# FrischMarkt ERP (simulated S/4HANA core)

SAP CAP service (OData V4 at `/odata/v4/erp`) that plays the ERP in the FrischMarkt project:
suppliers, products, stores, stock, sales orders, purchase orders, and goods receipts with the action `postGoodsReceipt` (idempotent per ASN number).

- Local: `npm install`, then `cds watch` (http://localhost:4004)
- Cloud Foundry: `npm run build:cf`, then `cf push`
- Users: mocked authentication in `package.json`. Replace the `CHANGE_ME_*` passwords before deploying.
