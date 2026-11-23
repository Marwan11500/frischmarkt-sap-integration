namespace frischmarkt.erp;

using { cuid, managed } from '@sap/cds/common';

// ─── Master data (Stammdaten) ───────────────────────────────

/** Who delivers our goods: fish, vegetables, dairy, drinks */
entity Suppliers {
  key ID       : String(20);          // e.g. SUP-FISH
      name     : String(100);
      category : String(20);          // FISH | VEG | DAIRY | DRINKS
      email    : String(100);
      products : Association to many Products on products.supplier = $self;
}

/** What we sell */
entity Products {
  key ID           : String(20);      // e.g. P-1001
      name         : String(100);
      category     : String(20);
      unit         : String(10);      // KG | PC | L
      price        : Decimal(10,2);
      currency     : String(3) default 'EUR';
      reorderLevel : Integer;          // below this → reorder
      reorderQty   : Integer;          // how much to order
      supplier     : Association to Suppliers;
}

/** Our supermarkets */
entity Stores {
  key ID   : String(20);              // e.g. S-ESSEN-01
      name : String(100);
      city : String(50);
}

/** How much of each product each store has */
entity Stock {
  key store    : Association to Stores;
  key product  : Association to Products;
      quantity : Integer;
}

// ─── Transactional data (Bewegungsdaten) ────────────────────

/** Customer orders coming from the online shop */
entity SalesOrders : cuid, managed {
  externalId    : String(40);         // order number from the online shop
  store         : Association to Stores;
  customerEmail : String(100);
  status        : String(20) default 'NEW';
  totalAmount   : Decimal(12,2);
  currency      : String(3) default 'EUR';
  items         : Composition of many SalesOrderItems on items.parent = $self;
}

entity SalesOrderItems : cuid {
  parent   : Association to SalesOrders;
  product  : Association to Products;
  quantity : Integer;
  price    : Decimal(10,2);
}

/** Orders WE send to our suppliers when stock is low */
entity PurchaseOrders : cuid, managed {
  supplier : Association to Suppliers;
  store    : Association to Stores;
  status   : String(20) default 'SENT';
  items    : Composition of many PurchaseOrderItems on items.parent = $self;
}

entity PurchaseOrderItems : cuid {
  parent   : Association to PurchaseOrders;
  product  : Association to Products;
  quantity : Integer;
}

/** Goods receipts (Wareneingang): goods that arrived in a store, booked from a supplier's
    shipping notice (ASN = Advance Shipping Notice). In S/4HANA: material document, MIGO, movement type 101. */
entity GoodsReceipts : cuid, managed {
  asnNumber : String(40);             // the supplier's shipping notice number, e.g. ASN-FISH-0001
  supplier  : Association to Suppliers;
  store     : Association to Stores;
  status    : String(20) default 'BOOKED';
  items     : Composition of many GoodsReceiptItems on items.parent = $self;
}

entity GoodsReceiptItems : cuid {
  parent   : Association to GoodsReceipts;
  product  : Association to Products;
  quantity : Integer;
}
