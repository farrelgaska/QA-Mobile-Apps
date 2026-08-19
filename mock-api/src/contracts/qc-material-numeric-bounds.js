const DECIMAL = String.raw`[0-9]+(?:[.,][0-9]+)?`;
const UNIT = String.raw`[A-Za-z]+`;

const patterns = {
  asymmetricPercentage: new RegExp(
    String.raw`^\s*(${DECIMAL})\s*(?:${UNIT})?\s*\+\s*(${DECIMAL})\s*%\s*-\s*(${DECIMAL})\s*%\s*$`,
    'i'
  ),
  symmetricPercentage: new RegExp(
    String.raw`^\s*(${DECIMAL})\s*(?:${UNIT})?\s*±\s*(${DECIMAL})\s*%\s*$`,
    'i'
  ),
  absoluteTolerance: new RegExp(
    String.raw`^\s*(${DECIMAL})\s*(?:${UNIT})?\s*±\s*(${DECIMAL})\s*(?:${UNIT})?\s*$`,
    'i'
  ),
  explicitRange: new RegExp(
    String.raw`^\s*(${DECIMAL})\s*-\s*(${DECIMAL})\s*(?:${UNIT})?\s*$`,
    'i'
  ),
  explicitMinimum: new RegExp(
    String.raw`^\s*(?:≥|>=|minimal\s+)\s*(${DECIMAL})\s*(?:${UNIT})?\s*$`,
    'i'
  ),
  exactNumber: new RegExp(
    String.raw`^\s*(${DECIMAL})\s*(?:${UNIT})?\s*$`,
    'i'
  )
};

const decimal = value => Number(value.replace(',', '.'));

const range = (minValue, maxValue, format) => ({
  validationType: 'RANGE',
  minValue,
  maxValue,
  format
});

const deriveQcMaterialNumericBounds = (standardText, validationType = null) => {
  if (typeof standardText !== 'string') return null;

  let match = standardText.match(patterns.asymmetricPercentage);
  if (match) {
    const primary = decimal(match[1]);
    const upperPercentage = decimal(match[2]);
    const lowerPercentage = decimal(match[3]);
    return range(
      primary * (1 - lowerPercentage / 100),
      primary * (1 + upperPercentage / 100),
      'ASYMMETRIC_PERCENTAGE_TOLERANCE'
    );
  }

  match = standardText.match(patterns.symmetricPercentage);
  if (match) {
    const primary = decimal(match[1]);
    const percentage = decimal(match[2]);
    return range(
      primary * (1 - percentage / 100),
      primary * (1 + percentage / 100),
      'SYMMETRIC_PERCENTAGE_TOLERANCE'
    );
  }

  match = standardText.match(patterns.absoluteTolerance);
  if (match) {
    const primary = decimal(match[1]);
    const tolerance = decimal(match[2]);
    return range(
      primary - tolerance,
      primary + tolerance,
      'ABSOLUTE_TOLERANCE'
    );
  }

  match = standardText.match(patterns.explicitRange);
  if (match) {
    const minValue = decimal(match[1]);
    const maxValue = decimal(match[2]);
    if (minValue > maxValue) return null;
    return range(minValue, maxValue, 'EXPLICIT_RANGE');
  }

  match = standardText.match(patterns.explicitMinimum);
  if (match) {
    return {
      validationType: 'MIN',
      minValue: decimal(match[1]),
      maxValue: null,
      format: 'EXPLICIT_MINIMUM'
    };
  }

  if (String(validationType || '').toUpperCase() === 'EXACT') {
    match = standardText.match(patterns.exactNumber);
    if (match) {
      const exactValue = decimal(match[1]);
      return {
        validationType: 'EXACT',
        minValue: exactValue,
        maxValue: exactValue,
        format: 'VALIDATION_QUALIFIED_EXACT'
      };
    }
  }

  return null;
};

module.exports = { deriveQcMaterialNumericBounds };
