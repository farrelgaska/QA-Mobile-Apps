const { getPool } = require('../database/postgres');
const { canonicalTemplateInput, mapTemplateAggregate } = require('./postgres/mappers');
const { notFound, translatePostgresError } = require('./repository-errors');

const ROOT_COLUMNS = `id, type, name, description, form_code, category, segment,
  standard_code, is_active, workflow_status, version, migration_metadata, created_at, updated_at`;

class PostgresTemplateRepository {
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
      `select ${ROOT_COLUMNS} from public.qc_templates where id = $1${lock ? ' for update' : ''}`,
      [id]
    );
    if (!rootResult.rows[0]) return undefined;
    const itemResult = await executor.query(
      'select * from public.qc_template_items where template_id = $1 order by position, id',
      [id]
    );
    return mapTemplateAggregate(rootResult.rows[0], itemResult.rows);
  }

  async findAll() {
    const roots = await this.pool.query(`select ${ROOT_COLUMNS} from public.qc_templates order by created_at, id`);
    if (roots.rows.length === 0) return [];
    const ids = roots.rows.map(row => row.id);
    const items = await this.pool.query(
      'select * from public.qc_template_items where template_id = any($1::text[]) order by template_id, position, id',
      [ids]
    );
    const byTemplate = new Map(ids.map(id => [id, []]));
    for (const item of items.rows) byTemplate.get(item.template_id).push(item);
    return roots.rows.map(row => mapTemplateAggregate(row, byTemplate.get(row.id)));
  }

  findById(id) {
    return this._findById(this.pool, id);
  }

  async _insertItems(client, templateId, items) {
    for (const item of items) {
      const rule = item.validation_rule || {};
      await client.query(
        `insert into public.qc_template_items (
          template_id, id, parameter_name, input_type, standard_text, unit,
          is_required, required_photo, is_active, is_critical, position, choices,
          category, validation_type, validation_min_value, validation_max_value,
          validation_exact_value, migration_metadata
        ) values (
          $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12,
          $13, $14, $15, $16, $17, $18
        )`,
        [
          templateId, item.id, item.parameter_name, item.input_type, item.standard_text,
          item.unit, item.is_required, item.required_photo, item.is_active,
          item.is_critical, item.position, item.choices, item.category,
          rule.type ?? null, rule.min_value ?? null, rule.max_value ?? null,
          rule.exact_value ?? null, item.migration_metadata
        ]
      );
    }
  }

  async _insertRoot(client, template) {
    await client.query(
      `insert into public.qc_templates (${ROOT_COLUMNS})
       values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)`,
      [
        template.id, template.type, template.name, template.description,
        template.form_code, template.category, template.segment, template.standard_code,
        template.is_active, template.workflow_status, template.version,
        template.migration_metadata, template.created_at, template.updated_at
      ]
    );
  }

  async create(input) {
    const template = canonicalTemplateInput(input);
    try {
      return await this._transaction(async client => {
        await this._insertRoot(client, template);
        await this._insertItems(client, template.id, template.checklist_items);
        return this._findById(client, template.id);
      });
    } catch (error) {
      throw translatePostgresError(error, 'Template', template.id);
    }
  }

  async update(id, patch) {
    return this._transaction(async client => {
      const current = await this._findById(client, id, true);
      if (!current) throw notFound(`Template with ID ${id} not found`);
      const merged = { ...current, ...patch, id };
      const aliases = [
        ['formCode', 'form_code'], ['standardCode', 'standard_code'],
        ['isActive', 'is_active'], ['workflowStatus', 'workflow_status'],
        ['checklistItems', 'checklist_items']
      ];
      for (const [legacy, canonical] of aliases) {
        if (patch[legacy] !== undefined && patch[canonical] === undefined) merged[canonical] = patch[legacy];
      }
      const template = canonicalTemplateInput(merged);
      template.created_at = current.created_at;
      template.updated_at = new Date().toISOString();

      await client.query(
        `update public.qc_templates set type=$2, name=$3, description=$4, form_code=$5,
          category=$6, segment=$7, standard_code=$8, is_active=$9,
          workflow_status=$10, version=$11, migration_metadata=$12, updated_at=$13
         where id=$1`,
        [
          id, template.type, template.name, template.description, template.form_code,
          template.category, template.segment, template.standard_code,
          template.is_active, template.workflow_status, template.version,
          template.migration_metadata, template.updated_at
        ]
      );
      await client.query('delete from public.qc_template_items where template_id = $1', [id]);
      await this._insertItems(client, id, template.checklist_items);
      return this._findById(client, id);
    });
  }

  async deleteChecklistItem(templateId, itemId) {
    return this._transaction(async client => {
      const result = await client.query(
        'delete from public.qc_template_items where template_id = $1 and id = $2 returning id',
        [templateId, itemId]
      );
      if (result.rowCount === 0) {
        const template = await this._findById(client, templateId, true);
        if (!template) throw notFound(`Template with ID ${templateId} not found`);
        throw notFound(`Checklist parameter with ID ${itemId} not found in template ${templateId}`);
      }
      await client.query('update public.qc_templates set updated_at = now() where id = $1', [templateId]);
      return this._findById(client, templateId);
    });
  }
}

module.exports = { PostgresTemplateRepository };
