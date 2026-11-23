<?xml version="1.0" encoding="UTF-8"?>
<!--
  FrischMarkt · Phase 3 · XSLT mapping
  Input : ONE low-stock line from the ERP (after the splitter), e.g.
          <LowStock><storeId>S-ESSEN-01</storeId><productId>P-1001</productId> ... </LowStock>
  Output: ONE purchase order in the supplier's language.
  "priority" comes from the exchange property set in the Router route (EXPRESS / STANDARD).
-->
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="xml" indent="yes" omit-xml-declaration="yes"/>

  <!-- CPI hands every header and exchange property to the XSLT as a parameter with the same name -->
  <xsl:param name="priority" select="'STANDARD'"/>

  <xsl:template match="/">
    <!-- //productId/.. = "the element that contains productId", whatever the adapter called it -->
    <xsl:variable name="row" select="(//productId/..)[1]"/>
    <xsl:variable name="today" select="format-date(current-date(), '[Y0001][M01][D01]')"/>
    <PurchaseOrder>
      <poNumber><xsl:value-of select="concat('PO-', $today, '-', $row/storeId, '-', $row/productId)"/></poNumber>
      <supplier><xsl:value-of select="$row/supplierId"/></supplier>
      <priority><xsl:value-of select="$priority"/></priority>
      <deliverTo><xsl:value-of select="$row/storeId"/></deliverTo>
      <line>
        <sku><xsl:value-of select="$row/productId"/></sku>
        <description><xsl:value-of select="$row/productName"/></description>
        <quantity><xsl:value-of select="$row/reorderQty"/></quantity>
      </line>
    </PurchaseOrder>
  </xsl:template>
</xsl:stylesheet>
