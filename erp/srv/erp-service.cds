using { frischmarkt.erp as db } from '../db/schema';

/**
 * The "ERP" of FrischMarkt — plays the role of S/4HANA in our project.
 * Reachable as OData V4 at /odata/v4/erp
 */
@requires: 'authenticated-user'
service ErpService {

  entity Suppliers          as projection on db.Suppliers;
  entity Products           as projection on db.Products;
  entity Stores             as projection on db.Stores;
  entity Stock              as projection on db.Stock;
  entity SalesOrders        as projection on db.SalesOrders;
  entity SalesOrderItems    as projection on db.SalesOrderItems;
  entity PurchaseOrders     as projection on db.PurchaseOrders;
  entity PurchaseOrderItems as projection on db.PurchaseOrderItems;

  /** Phase 4: booked deliveries (read-only, they are created only by the action below) */
  @readonly entity GoodsReceipts     as projection on db.GoodsReceipts;
  @readonly entity GoodsReceiptItems as projection on db.GoodsReceiptItems;

  /** One line of a delivery */
  type ReceiptLine {
    productId : String(20);
    quantity  : Integer;
  }

  /** Phase 4: book a delivery → stock goes up.
      Idempotent: the same asnNumber twice is booked only once. */
  action postGoodsReceipt(asnNumber  : String(40),
                          supplierId : String(20),
                          storeId    : String(20),
                          items      : many ReceiptLine) returns GoodsReceipts;

  /** Read-only list: everything that must be re-ordered */
  @readonly
  entity LowStock as select from db.Stock {
    key store.ID             as storeId,
    key product.ID           as productId,
        product.name         as productName,
        product.category     as category,
        quantity,
        product.reorderLevel as reorderLevel,
        product.reorderQty   as reorderQty,
        product.supplier.ID  as supplierId
  } where quantity < product.reorderLevel;
}
