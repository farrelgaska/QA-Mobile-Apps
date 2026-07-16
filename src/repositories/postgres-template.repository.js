const { getPool } = require('../database/postgres');
const {
  canonicalTemplateInput,
  canonicalTemplateItemInput,
  mapTemplateAggregate,
  mapTemplateItemRow,
  mergeTemplateItemPatch
} = require('./postgres/mappers');
const { conflict, notFound, translatePostgresError } = require('./repository-errors');

const ROOT_COLUMNS = `id, type, name, description, form_code, category, segment,
  standard_code, is_active, workflow_status, version, migration_metadata, created_at, updated_at`;

const serializeChoiceOptions = choiceOptions => {
  if (!Array.isArray(choiceOptions)) {
    const error = new Error('choice_options must be an array');
    error.statusCode = 400;
    throw error;
  }
  return JSON.stringify(choiceOptions);
};

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

  async _findItem(executor, templateId, itemId) {
    const result = await executor.query(
      'select * from public.qc_template_items where template_id = $1 and id = $2',
      [templateId, itemId]
    );
    return result.rows[0] ? mapTemplateItemRow(result.rows[0]) : undefined;
  }

  _nextItemId(templateId, items) {
    const existing = new Set(items.map(item => item.id));
    let sequence = 1;
    while (existing.has(`${templateId}-C${String(sequence).padStart(2, '0')}`)) sequence += 1;
    return `${templateId}-C${String(sequence).padStart(2, '0')}`;
  }

  async _insertItems(client, templateId, items) {
    for (const item of items) {
      const rule = item.validation_rule || {};
      await client.query(
        `insert into public.qc_template_items (
          template_id, id, parameter_name, input_type, standard_text, min_value, max_value, unit,
          is_required, required_photo, is_active, is_critical, position, choices,
          choice_options, category, validation_type, validation_min_value, validation_max_value,
          validation_exact_value, migration_metadata
        ) values (
          $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12,
          $13, $14, $15::jsonb, $16, $17, $18, $19, $20, $21
        )`,
        [
          templateId, item.id, item.parameter_name, item.input_type, item.standard_text,
          item.min_value, item.max_value, item.unit, item.is_required, item.required_photo,
          item.is_active, item.is_critical, item.position, item.choices,
          serializeChoiceOptions(item.choice_options),
          item.category,
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
      const replacesItems = patch.checklist_items !== undefined || patch.checklistItems !== undefined;
      const template = canonicalTemplateInput(replacesItems ? merged : { ...merged, checklist_items: [] });
      if (!replacesItems) template.checklist_items = current.checklist_items;
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
      if (replacesItems) {
        await client.query('delete from public.qc_template_items where template_id = $1', [id]);
        await this._insertItems(client, id, template.checklist_items);
      }
      return this._findById(client, id);
    });
  }

  async createChecklistItem(templateId, input) {
    try {
      return await this._transaction(async client => {
        const template = await this._findById(client, templateId, true);
        if (!template) throw notFound(`Template with ID ${templateId} not found`);
        const id = input.id || this._nextItemId(templateId, template.checklist_items);
        if (template.checklist_items.some(item => item.id === id)) {
          throw conflict(`Checklist parameter with ID ${id} already exists in template ${templateId}`);
        }
        const nextPosition = template.checklist_items.reduce(
          (maximum, item) => Math.max(maximum, item.position),
          -1
        ) + 1;
        const item = canonicalTemplateItemInput({ ...input, id, position: input.position ?? nextPosition }, nextPosition);
        await this._insertItems(client, templateId, [item]);
        await client.query('update public.qc_templates set updated_at = now() where id = $1', [templateId]);
        return this._findItem(client, templateId, id);
      });
    } catch (error) {
      if (error?.code === '23505') {
        throw conflict(`Checklist parameter or position already exists in template ${templateId}`);
      }
      throw error;
    }
  }

  async updateChecklistItem(templateId, itemId, patch) {
    return this._transaction(async client => {
      const template = await this._findById(client, templateId, true);
      if (!template) throw notFound(`Template with ID ${templateId} not found`);
      const current = template.checklist_items.find(item => item.id === itemId);
      if (!current) throw notFound(`Checklist parameter with ID ${itemId} not found in template ${templateId}`);
      const item = mergeTemplateItemPatch(current, patch);
      const rule = item.validation_rule || {};
      try {
        await client.query(
          `update public.qc_template_items set
            parameter_name=$3, input_type=$4, standard_text=$5, min_value=$6, max_value=$7,
            unit=$8, is_required=$9, required_photo=$10, is_active=$11, is_critical=$12,
            position=$13, choices=$14, choice_options=$15::jsonb, category=$16,
            validation_type=$17, validation_min_value=$18, validation_max_value=$19,
            validation_exact_value=$20, migration_metadata=$21
           where template_id=$1 and id=$2`,
          [
            templateId, itemId, item.parameter_name, item.input_type, item.standard_text,
            item.min_value, item.max_value, item.unit, item.is_required, item.required_photo,
            item.is_active, item.is_critical, item.position, item.choices,
            serializeChoiceOptions(item.choice_options),
            item.category, rule.type ?? null, rule.min_value ?? null, rule.max_value ?? null,
            rule.exact_value ?? null, item.migration_metadata
          ]
        );
      } catch (error) {
        if (error?.code === '23505') throw conflict(`Checklist position already exists in template ${templateId}`);
        throw error;
      }
      await client.query('update public.qc_templates set updated_at = now() where id = $1', [templateId]);
      return this._findItem(client, templateId, itemId);
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

  async delete(id) {
    return this._transaction(async client => {
      const result = await client.query(
        'delete from public.qc_templates where id = $1 returning id',
        [id]
      );
      if (result.rowCount === 0) throw notFound(`Template with ID ${id} not found`);
    });
  }
}

module.exports = { PostgresTemplateRepository };
