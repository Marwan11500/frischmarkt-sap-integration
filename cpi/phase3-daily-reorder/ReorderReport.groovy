/*
 * FrischMarkt · Phase 3 · Groovy script "Build reorder report"
 *
 * Input : the Gather result = all supplier answers glued together, e.g.
 *         <multimap:Messages><multimap:Message1>
 *             <PurchaseOrderConfirmation>...</PurchaseOrderConfirmation>
 *             <PurchaseOrderConfirmation>...</PurchaseOrderConfirmation>
 *         </multimap:Message1></multimap:Messages>
 * Output: a short, human-readable report (text/plain) as the message body,
 *         plus the same report attached to the Message Processing Log (MPL),
 *         plus two properties for later steps: reorderConfirmed, reorderRejected.
 *
 * Uses only plain Java XML classes, so it runs on every Groovy version CPI offers.
 */
import com.sap.gateway.ip.core.customdev.util.Message
import javax.xml.parsers.DocumentBuilderFactory
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter

def Message processData(Message message) {
    String xml = message.getBody(String) ?: ''
    List<Map> lines = []

    if (xml.trim()) {
        def factory = DocumentBuilderFactory.newInstance()
        // security: never follow DOCTYPE instructions inside the XML (prevents XXE attacks)
        factory.setFeature('http://apache.org/xml/features/disallow-doctype-decl', true)
        factory.setNamespaceAware(false)
        def doc = factory.newDocumentBuilder().parse(new ByteArrayInputStream(xml.getBytes('UTF-8')))
        // finds the answers no matter how deep Gather wrapped them
        def nodes = doc.getElementsByTagName('PurchaseOrderConfirmation')
        for (int i = 0; i < nodes.getLength(); i++) {
            def node = nodes.item(i)
            Map line = [:]
            def children = node.getChildNodes()
            for (int j = 0; j < children.getLength(); j++) {
                def child = children.item(j)
                if (child.getNodeType() == org.w3c.dom.Node.ELEMENT_NODE) {
                    line[child.getNodeName()] = child.getTextContent().trim()
                }
            }
            lines << line
        }
    }

    def confirmed = lines.findAll { it.status == 'CONFIRMED' }
    def rejected  = lines.findAll { it.status != 'CONFIRMED' }

    String now = ZonedDateTime.now(ZoneId.of('Europe/Berlin')).format(DateTimeFormatter.ofPattern('yyyy-MM-dd HH:mm'))
    def sb = new StringBuilder()
    sb.append("FrischMarkt daily reorder report · ${now}\n")
    sb.append("Lines: ${lines.size()} · confirmed: ${confirmed.size()} · rejected: ${rejected.size()}\n")
    sb.append('-' * 78).append('\n')

    lines.groupBy { it.supplier }.sort { it.key }.each { supplier, supplierLines ->
        sb.append("${supplier}\n")
        supplierLines.each { c ->
            String detail = c.status == 'CONFIRMED'
                    ? "delivery ${c.deliveryDate} (${c.supplierOrderId})"
                    : "REASON: ${c.reason}"
            sb.append(String.format('  %-11s %-7s x%-5s %-9s %-10s %s%n',
                    c.deliverTo, c.sku, c.quantity, c.priority, c.status, detail))
        }
    }
    if (rejected) {
        sb.append('-' * 78).append('\n')
        sb.append("ACTION NEEDED: ${rejected.size()} line(s) rejected. Buy elsewhere or call the supplier.\n")
    }

    String report = sb.toString()
    message.setBody(report)
    message.setHeader('Content-Type', 'text/plain; charset=utf-8')
    message.setProperty('reorderConfirmed', confirmed.size())
    message.setProperty('reorderRejected', rejected.size())
    // the filing label for the Data Store: today's date in Berlin, e.g. 20261118
    message.setProperty('reportDate', ZonedDateTime.now(ZoneId.of('Europe/Berlin')).format(DateTimeFormatter.ofPattern('yyyyMMdd')))

    def mpl = messageLogFactory.getMessageLog(message)
    if (mpl != null) {
        mpl.addAttachmentAsString('Reorder report', report, 'text/plain')
        mpl.setStringProperty('reorderRejected', rejected.size().toString())
    }
    return message
}
