const { masterDataRepository } = require('../repositories');
const AppError = require('../utils/AppError');

const queryString = (req, name, { required = false } = {}) => {
  const value = req.query[name];
  if (value === undefined && !required) return '';
  if (typeof value !== 'string' || (required && !value.trim())) {
    throw new AppError({
      status: 400,
      code: 'VALIDATION_ERROR',
      message: 'Data yang dikirim tidak valid.'
    });
  }
  return value;
};

const getMaterialFamilies = async (req, res, next) => {
  try {
    res.json(await masterDataRepository.findMaterialFamilies({
      q: queryString(req, 'q'),
      category: queryString(req, 'category')
    }));
  } catch (error) {
    next(error);
  }
};

const getVendors = async (req, res, next) => {
  try {
    res.json(await masterDataRepository.findVendors({
      q: queryString(req, 'q'),
      materialId: queryString(req, 'material_id')
    }));
  } catch (error) {
    next(error);
  }
};

const getMaterials = async (req, res, next) => {
  try {
    res.json(await masterDataRepository.findMaterials({
      q: queryString(req, 'q'),
      vendor: queryString(req, 'vendor'),
      familyId: queryString(req, 'family_id')
    }));
  } catch (error) {
    next(error);
  }
};

const getMaterialById = async (req, res, next) => {
  try {
    const material = await masterDataRepository.findMaterialById(req.params.materialId);
    if (!material) {
      return next(new AppError({
        status: 404,
        code: 'NOT_FOUND',
        message: `Material dengan ID ${req.params.materialId} tidak ditemukan.`
      }));
    }
    res.json(material);
  } catch (error) {
    next(error);
  }
};

const getBrands = async (req, res, next) => {
  try {
    res.json(await masterDataRepository.findBrands({
      vendor: queryString(req, 'vendor', { required: true }),
      materialId: queryString(req, 'material_id', { required: true })
    }));
  } catch (error) {
    next(error);
  }
};

const getWarehouses = async (req, res, next) => {
  try {
    res.json(await masterDataRepository.findWarehouses({ q: queryString(req, 'q') }));
  } catch (error) {
    next(error);
  }
};

const getWarehouseByPlant = async (req, res, next) => {
  try {
    const warehouse = await masterDataRepository.findWarehouseByPlant(req.params.plant);
    if (!warehouse) {
      return next(new AppError({
        status: 404,
        code: 'NOT_FOUND',
        message: `Warehouse dengan plant ${req.params.plant} tidak ditemukan.`
      }));
    }
    res.json(warehouse);
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getMaterialFamilies,
  getVendors,
  getMaterials,
  getMaterialById,
  getBrands,
  getWarehouses,
  getWarehouseByPlant
};
