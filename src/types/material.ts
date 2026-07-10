export type MaterialStatus = 'Aktif' | 'Nonaktif';

export interface MaterialChecklistTemplate {
  id: string;
  name: string;
  standardLabel: string;
  unit: string;
  minVal?: number;
  maxVal?: number;
  requiredPhoto: boolean;
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
