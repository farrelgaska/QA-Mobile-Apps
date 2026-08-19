import type { ChecklistResult, QCReport, StandardResult } from '../types/report';

export function evaluateChecklistItem(
  actualValue: string,
  standardLabel: string
): ChecklistResult {
  const cleanActual = actualValue.trim();
  if (!cleanActual) {
    return 'NEEDS_REVIEW';
  }

  const actualNum = parseFloat(cleanActual.replace(/[^\d.-]/g, ''));

  // Case 1: Range "X - Y"
  const rangeMatch = standardLabel.match(/(\d+(?:\.\d+)?)\s*-\s*(\d+(?:\.\d+)?)/);
  if (rangeMatch && !isNaN(actualNum)) {
    const min = parseFloat(rangeMatch[1]);
    const max = parseFloat(rangeMatch[2]);
    return actualNum >= min && actualNum <= max ? 'PASS' : 'FAIL';
  }

  // Case 2: "min X"
  const minMatch = standardLabel.match(/min\s*(\d+(?:\.\d+)?)/i);
  if (minMatch && !isNaN(actualNum)) {
    const min = parseFloat(minMatch[1]);
    return actualNum >= min ? 'PASS' : 'FAIL';
  }

  // Case 3: "max X"
  const maxMatch = standardLabel.match(/max\s*(\d+(?:\.\d+)?)/i);
  if (maxMatch && !isNaN(actualNum)) {
    const max = parseFloat(maxMatch[1]);
    return actualNum <= max ? 'PASS' : 'FAIL';
  }

  // Case 4: Text-based/descriptive matches (case insensitive check)
  const cleanLabel = standardLabel.toLowerCase();
  const cleanActVal = cleanActual.toLowerCase();

  if (cleanLabel.includes(cleanActVal) || cleanActVal.includes(cleanLabel)) {
    return 'PASS';
  }

  if (cleanActVal === 'sesuai' || cleanActVal === 'baik' || cleanActVal === 'kencang' || cleanActVal === 'tegak lurus') {
    return 'PASS';
  }

  // If actual number is parsed and matches single numbers in label
  const singleNumMatch = standardLabel.match(/(\d+(?:\.\d+)?)/);
  if (singleNumMatch && !isNaN(actualNum)) {
    const target = parseFloat(singleNumMatch[1]);
    return actualNum === target ? 'PASS' : 'FAIL';
  }

  return 'NEEDS_REVIEW';
}

export function getReportStandardSummary(report: QCReport): StandardResult {
  if (report.checklistItems.length === 0) {
    return 'Perlu Review';
  }

  let hasFail = false;
  let hasReview = false;

  for (const item of report.checklistItems) {
    if (item.result === 'FAIL') {
      hasFail = true;
    } else if (item.result === 'NEEDS_REVIEW') {
      hasReview = true;
    }
  }

  if (hasFail) {
    return 'Tidak Lulus';
  }
  if (hasReview) {
    return 'Perlu Review';
  }
  return 'Lulus';
}
