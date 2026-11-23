<?xml version="1.0" encoding="UTF-8"?>
<!--
  FrischMarkt · Phase 4 · XSLT mapping (in FM_03b)
  Input : what the Data Store "Select" step returns: the inbox envelope with ONE shipping notice, e.g.
          <messages><message id="ASN-FISH-0001"><ShippingNotice>…</ShippingNotice></message></messages>
  Output: the JSON body for the ERP action postGoodsReceipt, e.g.
          {"asnNumber":"ASN-FISH-0001","supplierId":"SUP-FISH","storeId":"S-ESSEN-01",
           "items":[{"productId":"P-1001","quantity":30}]}
  XSLT usually writes XML; with method="text" it can write any text, here JSON.
-->
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="text" encoding="UTF-8"/>

  <xsl:template match="/">
    <!-- //ShippingNotice = "find the notice, however deep the envelope wraps it" -->
    <xsl:variable name="asn" select="(//ShippingNotice)[1]"/>
    <xsl:text>{"asnNumber":"</xsl:text><xsl:value-of select="normalize-space($asn/asnNumber)"/>
    <xsl:text>","supplierId":"</xsl:text><xsl:value-of select="normalize-space($asn/supplier)"/>
    <xsl:text>","storeId":"</xsl:text><xsl:value-of select="normalize-space($asn/deliverTo)"/>
    <xsl:text>","items":[</xsl:text>
    <xsl:for-each select="$asn/line">
      <xsl:if test="position() &gt; 1"><xsl:text>,</xsl:text></xsl:if>
      <xsl:text>{"productId":"</xsl:text><xsl:value-of select="normalize-space(sku)"/>
      <xsl:text>","quantity":</xsl:text><xsl:value-of select="number(quantity)"/>
      <xsl:text>}</xsl:text>
    </xsl:for-each>
    <xsl:text>]}</xsl:text>
  </xsl:template>
</xsl:stylesheet>
