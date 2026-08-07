import React from 'react';
import { Button } from '../ui/Button';
import { Modal } from '../ui/Modal';

interface IncompleteAdminDecisionModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const IncompleteAdminDecisionModal: React.FC<
  IncompleteAdminDecisionModalProps
> = ({ isOpen, onClose }) => (
  <Modal
    isOpen={isOpen}
    onClose={onClose}
    title="Keputusan Admin Belum Lengkap"
    footer={
      <Button id="dismiss-incomplete-admin-decisions" onClick={onClose}>
        Mengerti
      </Button>
    }
  >
    <p>
      Lengkapi seluruh Keputusan Admin pada setiap parameter di semua sampel
      dengan status Lulus atau Gagal sebelum melanjutkan.
    </p>
  </Modal>
);
