import React, { useEffect, useState } from 'react';
import type {
  ApiTemplateChecklistItem,
  ApiTemplateChecklistItemMutation,
  TemplateInputType,
} from '../../services/reportApi';
import { Button } from '../ui/Button';
import { Input } from '../ui/Input';
import { Select } from '../ui/Select';

interface TemplateParameterFormProps {
  initialItem?: ApiTemplateChecklistItem;
  isSaving?: boolean;
  onCancel: () => void;
  onSubmit: (item: ApiTemplateChecklistItemMutation) => Promise<void> | void;
}

const optionLabel = (
  item: ApiTemplateChecklistItem | undefined,
  outcome: 'PASS' | 'FAIL',
  fallback: string
) => item?.choiceOptions.find(option => option.outcome === outcome)?.label || fallback;

export const TemplateParameterForm: React.FC<TemplateParameterFormProps> = ({
  initialItem,
  isSaving = false,
  onCancel,
  onSubmit,
}) => {
  const [parameterName, setParameterName] = useState('');
  const [inputType, setInputType] = useState<TemplateInputType>('number');
  const [standardText, setStandardText] = useState('');
  const [minValue, setMinValue] = useState('');
  const [maxValue, setMaxValue] = useState('');
  const [unit, setUnit] = useState('');
  const [passLabel, setPassLabel] = useState('Sesuai');
  const [failLabel, setFailLabel] = useState('Tidak Sesuai');
  const [isRequired, setIsRequired] = useState(true);
  const [requiredPhoto, setRequiredPhoto] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setParameterName(initialItem?.parameterName ?? '');
    setInputType(initialItem?.inputType ?? 'number');
    setStandardText(initialItem?.standardText ?? '');
    setMinValue(initialItem?.minValue?.toString() ?? '');
    setMaxValue(initialItem?.maxValue?.toString() ?? '');
    setUnit(initialItem?.unit ?? '');
    setPassLabel(optionLabel(initialItem, 'PASS', 'Sesuai'));
    setFailLabel(optionLabel(initialItem, 'FAIL', 'Tidak Sesuai'));
    setIsRequired(initialItem?.isRequired ?? true);
    setRequiredPhoto(initialItem?.requiredPhoto ?? false);
    setError(null);
  }, [initialItem]);

  const changeInputType = (nextType: string) => {
    const next = nextType as TemplateInputType;
    setInputType(next);
    setError(null);
    if (next === 'text') {
      setMinValue('');
      setMaxValue('');
      setUnit('');
      setPassLabel('Sesuai');
      setFailLabel('Tidak Sesuai');
    } else if (next === 'choice') {
      setMinValue('');
      setMaxValue('');
      setUnit('');
    } else {
      setPassLabel('Sesuai');
      setFailLabel('Tidak Sesuai');
    }
  };

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    const trimmedName = parameterName.trim();
    const trimmedStandard = standardText.trim();
    if (!trimmedName || !trimmedStandard) {
      setError('Nama parameter dan acuan standar wajib diisi.');
      return;
    }

    const parsedMin = minValue === '' ? null : Number(minValue);
    const parsedMax = maxValue === '' ? null : Number(maxValue);
    if (inputType === 'number' && parsedMin !== null && parsedMax !== null && parsedMin > parsedMax) {
      setError('Nilai minimum tidak boleh lebih besar dari nilai maksimum.');
      return;
    }
    if (inputType === 'choice') {
      if (!passLabel.trim() || !failLabel.trim()) {
        setError('Opsi Sesuai dan Opsi Tidak Sesuai wajib diisi.');
        return;
      }
      if (passLabel.trim().toLocaleLowerCase() === failLabel.trim().toLocaleLowerCase()) {
        setError('Label Opsi Sesuai dan Opsi Tidak Sesuai harus berbeda.');
        return;
      }
    }

    await onSubmit({
      parameterName: trimmedName,
      inputType,
      standardText: trimmedStandard,
      minValue: inputType === 'number' ? parsedMin : null,
      maxValue: inputType === 'number' ? parsedMax : null,
      unit: inputType === 'number' ? unit.trim() || null : null,
      choiceOptions: inputType === 'choice' ? [
        { id: 'pass', label: passLabel.trim(), value: 'PASS', outcome: 'PASS', position: 0 },
        { id: 'fail', label: failLabel.trim(), value: 'FAIL', outcome: 'FAIL', position: 1 },
      ] : [],
      choices: [],
      isRequired,
      requiredPhoto,
      isActive: initialItem?.isActive ?? true,
      isCritical: initialItem?.isCritical ?? false,
      position: initialItem?.position,
    });
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <Input
        id="parameter-name"
        label="Nama Parameter / Instruksi"
        value={parameterName}
        onChange={event => setParameterName(event.target.value)}
        required
      />
      <Select
        id="parameter-input-type"
        label="Tipe Input"
        value={inputType}
        onChange={changeInputType}
        options={[
          { value: 'number', label: 'Nilai Angka' },
          { value: 'text', label: 'Teks' },
          { value: 'choice', label: 'Pilihan Kriteria' },
        ]}
      />
      <Input
        id="parameter-standard"
        label="Acuan Standar"
        value={standardText}
        onChange={event => setStandardText(event.target.value)}
        required
      />

      {inputType === 'number' && (
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
          <Input id="parameter-min" label="Nilai Minimum" type="number" step="any" value={minValue} onChange={event => setMinValue(event.target.value)} />
          <Input id="parameter-max" label="Nilai Maksimum" type="number" step="any" value={maxValue} onChange={event => setMaxValue(event.target.value)} />
          <Input id="parameter-unit" label="Satuan" value={unit} onChange={event => setUnit(event.target.value)} />
        </div>
      )}

      {inputType === 'choice' && (
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <Input id="parameter-pass-label" label="Opsi Sesuai" value={passLabel} onChange={event => setPassLabel(event.target.value)} required />
          <Input id="parameter-fail-label" label="Opsi Tidak Sesuai" value={failLabel} onChange={event => setFailLabel(event.target.value)} required />
        </div>
      )}

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 py-2">
        <label className="flex items-center gap-2 text-xs font-semibold text-gray-700 cursor-pointer">
          <input type="checkbox" checked={isRequired} onChange={event => setIsRequired(event.target.checked)} className="h-4 w-4 text-[#006B5A] border-gray-300 rounded focus:ring-[#006B5A]" />
          Wajib Diisi
        </label>
        <label className="flex items-center gap-2 text-xs font-semibold text-gray-700 cursor-pointer">
          <input type="checkbox" checked={requiredPhoto} onChange={event => setRequiredPhoto(event.target.checked)} className="h-4 w-4 text-[#006B5A] border-gray-300 rounded focus:ring-[#006B5A]" />
          Wajib Unggah Foto
        </label>
      </div>

      {error && <div className="text-xs font-medium text-red-600 bg-red-50 border border-red-200 rounded-lg p-3">{error}</div>}

      <div className="flex justify-end gap-2 pt-2 border-t border-gray-100">
        <Button variant="outline" type="button" onClick={onCancel} disabled={isSaving}>Batal</Button>
        <Button variant="primary" type="submit" className="bg-[#006B5A] hover:bg-[#005244]" disabled={isSaving}>
          {isSaving ? 'Menyimpan...' : 'Simpan Parameter'}
        </Button>
      </div>
    </form>
  );
};
