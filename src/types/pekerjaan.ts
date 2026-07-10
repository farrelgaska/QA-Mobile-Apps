export interface PekerjaanChecklistTemplate {
  id: string;
  name: string;
  isActive: boolean;
}

export interface QCPekerjaan {
  id: string;
  name: string;
  category: string;
  segment: 'provisioning' | 'assurance' | 'construction';
  checklistCount: number;
  isActive: boolean;
  updatedAt: string;
  checklistItems: PekerjaanChecklistTemplate[];
}
