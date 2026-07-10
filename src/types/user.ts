export interface Site {
  id: string;
  name: string;
  area: string;
  zona: string;
}

export interface AdminUser {
  nik: string;
  name: string;
  role: 'Admin';
}

export interface QAStaffUser {
  nik: string;
  name: string;
  role: 'QA Staff';
  siteName?: string;
}
