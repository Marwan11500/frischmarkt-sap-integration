"""
FrischMarkt · Phase 3 · Supplier order endpoint (AWS Lambda, Python 3.12)

Plays the role of ALL four suppliers (one "supplier portal").
CPI sends one <PurchaseOrder> (XML) per low-stock line.
The function answers with a <PurchaseOrderConfirmation> (XML):
  - CONFIRMED   → supplier will deliver (EXPRESS: tomorrow, STANDARD: in 2 days)
  - REJECTED    → supplier cannot deliver (HTTP 422), e.g. the item is sold out

Security: API Gateway checks the API key (x-api-key header) BEFORE
this code runs. Without a valid key the call never reaches Lambda (HTTP 403).
"""
import base64
import datetime
import uuid
import xml.etree.ElementTree as ET

# What each supplier can deliver (their own catalogue)
CATALOGUE = {
    "SUP-FISH":   {"P-1001", "P-1002", "P-1003"},
    "SUP-VEG":    {"P-2001", "P-2002", "P-2003"},
    "SUP-DAIRY":  {"P-3001", "P-3002"},
    "SUP-DRINKS": {"P-4001", "P-4002"},
}
# Planted problem: the drinks supplier itself is out of Apfelschorle
SOLD_OUT = {"P-4002": "Sold out at supplier until next week"}


def _xml_response(status_code, root):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/xml"},
        "body": ET.tostring(root, encoding="unicode"),
    }


def _confirmation(po, status, reason=None):
    root = ET.Element("PurchaseOrderConfirmation")
    for tag in ("poNumber", "supplier", "deliverTo", "sku", "quantity", "priority"):
        ET.SubElement(root, tag).text = po.get(tag, "")
    ET.SubElement(root, "status").text = status
    if status == "CONFIRMED":
        days = 1 if po.get("priority") == "EXPRESS" else 2
        delivery = datetime.date.today() + datetime.timedelta(days=days)
        prefix = po.get("supplier", "SUP").replace("SUP-", "")
        ET.SubElement(root, "supplierOrderId").text = f"{prefix}-{uuid.uuid4().hex[:8].upper()}"
        ET.SubElement(root, "deliveryDate").text = delivery.isoformat()
    else:
        ET.SubElement(root, "reason").text = reason
    return root


def _error(status_code, message):
    root = ET.Element("Error")
    ET.SubElement(root, "message").text = message
    return _xml_response(status_code, root)


def lambda_handler(event, context):
    body = event.get("body") or ""
    if event.get("isBase64Encoded"):
        body = base64.b64decode(body).decode("utf-8")

    try:
        doc = ET.fromstring(body)
    except ET.ParseError:
        return _error(400, "Body is not valid XML")
    if doc.tag != "PurchaseOrder":
        return _error(400, f"Expected <PurchaseOrder>, got <{doc.tag}>")

    po = {
        "poNumber":  doc.findtext("poNumber", ""),
        "supplier":  doc.findtext("supplier", ""),
        "priority":  doc.findtext("priority", "STANDARD"),
        "deliverTo": doc.findtext("deliverTo", ""),
        "sku":       doc.findtext("line/sku", ""),
        "quantity":  doc.findtext("line/quantity", ""),
    }

    if po["supplier"] not in CATALOGUE:
        return _error(400, f"Unknown supplier {po['supplier']}")
    if not po["quantity"].isdigit() or int(po["quantity"]) <= 0:
        return _error(400, "quantity must be a positive whole number")

    if po["sku"] not in CATALOGUE[po["supplier"]]:
        return _xml_response(422, _confirmation(po, "REJECTED",
                             f"{po['supplier']} does not sell {po['sku']}"))
    if po["sku"] in SOLD_OUT:
        return _xml_response(422, _confirmation(po, "REJECTED", SOLD_OUT[po["sku"]]))

    return _xml_response(200, _confirmation(po, "CONFIRMED"))
