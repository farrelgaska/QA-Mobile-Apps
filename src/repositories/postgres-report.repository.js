const { getPool } = require('../database/postgres');
const { canonicalReportInput, mapReportAggregate } = require('./postgres/mappers');
const { notFound, translatePostgresError } = require('./repository-errors');

const ROOT_COLUMNS = `id, type, template_id, form_code, title, status, staff_name,
  staff_nik, site_id, site_name, area, detail_location, general_info, staff_note,
  submitted_at, revision_number, migration_metadata, created_at, updated_at`;

class PostgresReportRepository {
  constructor(pool = getPool()) {
    this.pool = pool;
  }

  async _transaction(work) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const result = await work(client);
      await client.query('COMMIT');
      return result;
    } catch (error) {
      try { await client.query('ROLLBACK'); } catch (_) {}
      throw error;
    } finally {
      client.release();
    }
  }

  async _findById(executor, id, lock = false) {
    const rootResult = await executor.query(
      `select ${ROOT_COLUMNS} from public.qc_reports where id = $1${lock ? ' for update' : ''}`,
      [id]
    );
    if (!rootResult.rows[0]) return undefined;
    const [items, reviews, attachments] = await Promise.all([
      executor.query('select * from public.qc_report_items where report_id = $1 order by id', [id]),
      executor.query('select * from public.qc_report_admin_reviews where report_id = $1', [id]),
      executor.query('select * from public.qc_report_attachments where report_id = $1 order by sort_order, id', [id])
    ]);
    return mapReportAggregate(rootResult.rows[0], items.rows, reviews.rows[0] || null, attachments.rows);
  }

  async findAll() {
    const roots = await this.pool.query(`select ${ROOT_COLUMNS} from public.qc_reports order by created_at, id`);
    if (roots.rows.length === 0) return [];
    const ids = roots.rows.map(row => row.id);
    const [items, reviews, attachments] = await Promise.all([
      this.pool.query('select * from public.qc_report_items where report_id = any($1::text[]) order by report_id, id', [ids]),
      this.pool.query('select * from public.qc_report_admin_reviews where report_id = any($1::text[])', [ids]),
      this.pool.query('select * from public.qc_report_attachments where report_id = any($1::text[]) order by report_id, sort_order, id', [ids])
    ]);
    const itemMap = new Map(ids.map(id => [id, []]));
    const reviewMap = new Map();
    const attachmentMap = new Map(ids.map(id => [id, []]));
    for (const item of items.rows) itemMap.get(item.report_id).push(item);
    for (const review of reviews.rows) reviewMap.set(review.report_id, review);
    for (const attachment of attachments.rows) attachmentMap.get(attachment.report_id).push(attachment);
    return roots.rows.map(row => mapReportAggregate(
      row,
      itemMap.get(row.id),
      reviewMap.get(row.id) || null,
      attachmentMap.get(row.id)
    ));
  }

  findById(id) {
    return this._findById(this.pool, id);
  }

  async _writeRoot(client, report, update = false) {
    const values = [
      report.id, report.type, report.template_id || null, report.form_code,
      report.title, report.status, report.staff?.name || '', report.staff?.nik || '',
      report.location?.site_id || '', report.location?.site_name || '',
      report.location?.area || '', report.location?.detail_location || '',
      report.general_info, report.staff_note, report.submitted_at,
      report.revision_number, report.migration_metadata
    ];
    if (update) {
      await client.query(
        `update public.qc_reports set type=$2, template_id=$3, form_code=$4, title=$5,
          status=$6, staff_name=$7, staff_nik=$8, site_id=$9, site_name=$10,
          area=$11, detail_location=$12, general_info=$13, staff_note=$14,
          submitted_at=$15, revision_number=$16, migration_metadata=$17, updated_at=now()
         where id=$1`,
        values
      );
    } else {
      await client.query(
        `insert into public.qc_reports (
          id,type,template_id,form_code,title,status,staff_name,staff_nik,site_id,
          site_name,area,detail_location,general_info,staff_note,submitted_at,
          revision_number,migration_metadata
        ) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)`,
        values
      );
    }
  }

  async _writeChildren(client, report) {
    for (const item of report.checklist_items) {
      await client.query(
        `insert into public.qc_report_items (
          report_id,id,parameter_name,input_type,standard_text,unit,actual_value,
          staff_note,admin_evaluation,admin_note
        ) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
        [
          report.id, item.id, item.parameter_name, item.input_type, item.standard_text,
          item.unit, item.actual_value, item.staff_note, item.admin_evaluation, item.admin_note
        ]
      );
    }

    const review = report.admin_review;
    const reviewedBy = review?.reviewed_by ?? review?.reviewedBy ?? '';
    const conclusion = review?.conclusion ?? null;
    const hasAdminReview = typeof reviewedBy === 'string'
      && reviewedBy.trim() !== ''
      && ['PASSED', 'NOT_PASSED'].includes(conclusion);
    if (hasAdminReview) {
      await client.query(
        `insert into public.qc_report_admin_reviews
          (report_id,admin_note,conclusion,reviewed_at,reviewed_by)
         values ($1,$2,$3,$4,$5)`,
        [
          report.id, review.admin_note ?? review.adminNote ?? '', conclusion,
          review.reviewed_at ?? review.reviewedAt ?? null,
          reviewedBy
        ]
      );
    }

    for (let index = 0; index < report.general_photos.length; index++) {
      await client.query(
        `insert into public.qc_report_attachments
          (report_id,report_item_id,attachment_scope,uri,sort_order)
         values ($1,null,'GENERAL',$2,$3)`,
        [report.id, report.general_photos[index], index]
      );
    }
    for (const item of report.checklist_items) {
      for (let index = 0; index < item.item_photos.length; index++) {
        await client.query(
          `insert into public.qc_report_attachments
            (report_id,report_item_id,attachment_scope,uri,sort_order)
           values ($1,$2,'ITEM',$3,$4)`,
          [report.id, item.id, item.item_photos[index], index]
        );
      }
    }
  }

  async create(input) {
    const report = canonicalReportInput(input);
    try {
      return await this._transaction(async client => {
        await this._writeRoot(client, report, false);
        await this._writeChildren(client, report);
        return this._findById(client, report.id);
      });
    } catch (error) {
      throw translatePostgresError(error, 'Report', report.id);
    }
  }

  async update(id, patch) {
    return this._transaction(async client => {
      const current = await this._findById(client, id, true);
      if (!current) throw notFound(`Report with ID ${id} not found`);
      const merged = { ...current, ...patch, id };
      const aliases = [
        ['templateId', 'template_id'], ['formCode', 'form_code'],
        ['checklistItems', 'checklist_items'], ['staffNote', 'staff_note'],
        ['submittedAt', 'submitted_at'], ['adminReview', 'admin_review'],
        ['generalPhotos', 'general_photos'], ['revisionNumber', 'revision_number']
      ];
      for (const [legacy, canonical] of aliases) {
        if (patch[legacy] !== undefined && patch[canonical] === undefined) merged[canonical] = patch[legacy];
      }
      const report = canonicalReportInput(merged);
      await this._writeRoot(client, report, true);
      await client.query('delete from public.qc_report_attachments where report_id = $1', [id]);
      await client.query('delete from public.qc_report_admin_reviews where report_id = $1', [id]);
      await client.query('delete from public.qc_report_items where report_id = $1', [id]);
      await this._writeChildren(client, report);
      return this._findById(client, id);
    });
  }

  async delete(id) {
    return this._transaction(async client => {
      const result = await client.query(
        'delete from public.qc_reports where id = $1 returning id',
        [id]
      );
      if (result.rowCount === 0) throw notFound(`Report with ID ${id} not found`);
    });
  }
}

module.exports = { PostgresReportRepository };
