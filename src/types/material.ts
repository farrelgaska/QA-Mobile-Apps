export type MaterialStatus = 'Aktif' | 'Nonaktif';

export interface MaterialChecklistTemplate {
  id: string;
  name: string;
  standardLabel: string;
  unit: string;
  minVal?: number;
  maxVal?: number;
  inputType?: TemplateInputType;
  choiceOptions?: ApiTemplateChoiceOption[];
  isRequired?: boolean;
  requiredPhoto: boolean;
  isActive?: boolean;
  isCritical?: boolean;
  position?: number;
}

export interface QCMaterial {
  id: string;
  name: string;
  category: string;
  standard: string;
  checklistCount: number;
  status: MaterialStatus;
  updatedAt: string;
  checklistItems: MaterialChecklistTemplate[];
}
import type { ApiTemplateChoiceOption, TemplateInputType } from '../services/reportApi';
