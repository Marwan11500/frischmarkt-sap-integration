/*
 * FrischMarkt · Phase 3 · Groovy script "Set API key header"
 *
 * Reads a secret from CPI's Security Material (type: Secure Parameter)
 * and puts it into an HTTP header, so the secret never appears in the iFlow.
 *
 * It is reusable: two exchange properties tell it WHAT to read and WHERE to put it.
 *   apiKeyAlias  = name of the Secure Parameter   (e.g. FM_SUPPLIER_APIKEY)
 *   apiKeyHeader = name of the HTTP header         (e.g. x-api-key  or  APIKey)
 */
import com.sap.gateway.ip.core.customdev.util.Message
import com.sap.it.api.ITApiFactory
import com.sap.it.api.securestore.SecureStoreService

def Message processData(Message message) {
    String alias  = message.getProperty('apiKeyAlias')
    String header = message.getProperty('apiKeyHeader')
    if (!alias || !header) {
        throw new IllegalStateException('Set the properties apiKeyAlias and apiKeyHeader before this script')
    }

    def secureStore = ITApiFactory.getService(SecureStoreService.class, null)
    def credential  = secureStore.getUserCredential(alias)   // a Secure Parameter is read like this, too
    if (credential == null) {
        throw new IllegalStateException("Secure Parameter ${alias} is not deployed")
    }

    message.setHeader(header, new String(credential.getPassword()))
    return message
}
