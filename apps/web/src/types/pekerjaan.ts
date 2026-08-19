import type { ApiTemplateChoiceOption, TemplateInputType } from '../services/reportApi';

export interface PekerjaanChecklistTemplate {
  id: string;
  name: string;
  inputType?: TemplateInputType;
  standardText?: string;
  minValue?: number | null;
  maxValue?: number | null;
  unit?: string | null;
  choiceOptions?: ApiTemplateChoiceOption[];
  isRequired?: boolean;
  requiredPhoto?: boolean;
  isActive: boolean;
  isCritical?: boolean;
  position?: number;
}

export interface QCPekerjaan {
  id: string;
  formCode?: string;
  name: string;
  category: string;
  description?: string;
  segment: 'provisioning' | 'assurance' | 'construction';
  checklistCount: number;
  isActive: boolean;
  updatedAt: string;
  checklistItems: PekerjaanChecklistTemplate[];
}
