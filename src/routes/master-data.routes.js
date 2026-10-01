const express = require('express');
const controller = require('../controllers/master-data.controller');

const router = express.Router();

router.get('/material-families', controller.getMaterialFamilies);
router.get('/vendors', controller.getVendors);
router.get('/materials', controller.getMaterials);
router.get('/materials/:materialId', controller.getMaterialById);
router.get('/materials/:materialId/template', controller.getMaterialTemplate);
router.get('/brands', controller.getBrands);
router.get('/warehouses', controller.getWarehouses);
router.get('/warehouses/:plant', controller.getWarehouseByPlant);

module.exports = router;
