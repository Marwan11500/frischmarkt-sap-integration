import cds from '@sap/cds';

/**
 * Business logic of the FrischMarkt ERP.
 * Rule: a sales order may only be created if the store has enough stock.
 * If yes → stock goes down and the total amount is calculated.
 * If no  → the order is rejected with HTTP 409 (Conflict).
 */
export default class ErpService extends cds.ApplicationService {
  init() {
    const { SalesOrders, Products, Stock, Stores, Suppliers, GoodsReceipts } = this.entities;

    this.before('CREATE', SalesOrders, async (req) => {
      const order = req.data;
      if (!order.store_ID) return req.error(400, 'store_ID is missing');
      if (!order.items?.length) return req.error(400, 'Order has no items');

      let total = 0;
      for (const item of order.items) {
        const product = await SELECT.one.from(Products).where({ ID: item.product_ID });
        if (!product) return req.error(404, `Product ${item.product_ID} does not exist`);

        const stock = await SELECT.one.from(Stock)
          .where({ store_ID: order.store_ID, product_ID: item.product_ID });
        const available = stock?.quantity ?? 0;
        if (available < item.quantity) {
          return req.error(409,
            `Not enough stock for ${product.name} in ${order.store_ID}: ` +
            `wanted ${item.quantity}, available ${available}`);
        }

        item.price = product.price;
        total += Number(product.price) * item.quantity;
      }
      order.totalAmount = total.toFixed(2);
      order.status = 'CONFIRMED';
    });

    // after the order is saved: reduce the stock of the store
    this.after('CREATE', SalesOrders, async (_result, req) => {
      const order = req.data;
      for (const item of order.items ?? []) {
        await UPDATE(Stock)
          .with({ quantity: { '-=': item.quantity } })
          .where({ store_ID: order.store_ID, product_ID: item.product_ID });
      }
    });

    // ─── Phase 4: goods receipt (Wareneingang) ───────────────────────────
    // Rule 1: a delivery is booked only once (same asnNumber → return the existing receipt).
    // Rule 2: store, supplier and products must exist, and each product must come from that supplier.
    // Rule 3: booking a delivery raises the stock of the store.
    this.on('postGoodsReceipt', async (req) => {
      const { asnNumber, supplierId, storeId, items } = req.data;
      if (!asnNumber) return req.error(400, 'asnNumber is missing');
      if (!items?.length) return req.error(400, 'Delivery has no items');

      const existing = await SELECT.one.from(GoodsReceipts).where({ asnNumber });
      if (existing) {
        existing.status = 'ALREADY_BOOKED';
        return existing;
      }

      if (!await SELECT.one.from(Stores).where({ ID: storeId }))
        return req.error(400, `Store ${storeId} does not exist`);
      if (!await SELECT.one.from(Suppliers).where({ ID: supplierId }))
        return req.error(400, `Supplier ${supplierId} does not exist`);
      for (const line of items) {
        const product = await SELECT.one.from(Products).where({ ID: line.productId });
        if (!product) return req.error(400, `Product ${line.productId} does not exist`);
        if (product.supplier_ID !== supplierId)
          return req.error(400, `Product ${line.productId} is not supplied by ${supplierId}`);
        if (!(line.quantity > 0)) return req.error(400, `Quantity for ${line.productId} must be > 0`);
      }

      const receipt = {
        ID: cds.utils.uuid(),
        asnNumber,
        supplier_ID: supplierId,
        store_ID: storeId,
        status: 'BOOKED',
        items: items.map(l => ({ product_ID: l.productId, quantity: l.quantity }))
      };
      await INSERT.into(GoodsReceipts).entries(receipt);

      for (const line of items) {
        const changed = await UPDATE(Stock)
          .with({ quantity: { '+=': line.quantity } })
          .where({ store_ID: storeId, product_ID: line.productId });
        if (!changed) await INSERT.into(Stock)
          .entries({ store_ID: storeId, product_ID: line.productId, quantity: line.quantity });
      }

      return SELECT.one.from(GoodsReceipts).where({ ID: receipt.ID });
    });

    return super.init();
  }
}
