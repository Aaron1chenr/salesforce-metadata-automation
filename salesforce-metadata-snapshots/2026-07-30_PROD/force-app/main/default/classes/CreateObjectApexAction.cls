public with sharing class CreateObjectApexAction {
    private static final String API_VERSION = 'v67.0';
    private static final String NAMED_CREDENTIAL = 'Salesforce_Tooling';
    private static final String API_NAME_REGEX = '^[A-Za-z][A-Za-z0-9_]*__c$';

    public class Request {
        @InvocableVariable(required=true label='Object Config JSON')
        public String objectConfigJson;
    }

    public class Response {
        @InvocableVariable
        public Boolean success;

        @InvocableVariable
        public String message;

        @InvocableVariable
        public String objectApiName;

        @InvocableVariable
        public String details;
    }

    public class ObjectConfig {
        public String objectApiName;
        public String label;
        public String pluralLabel;
        public String description;
        public String sharingModel;
        public String deploymentStatus;
        public String nameFieldLabel;
        public List<FieldConfig> fields;
    }

    public class FieldConfig {
        public String fieldApiName;
        public String label;
        public String type;
        public Integer length;
        public Integer visibleLines;
        public Integer precision;
        public Integer scale;
        public Boolean required;
        public String defaultValue;
        public String description;
        public List<String> picklistValues;
    }

    @InvocableMethod(label='Create Object From JSON' description='Creates a custom object and fields from JSON using the Salesforce Tooling API.')
    public static List<Response> createObjects(List<Request> requests) {
        List<Response> responses = new List<Response>();

        if (requests == null || requests.isEmpty()) {
            responses.add(buildResponse(false, 'No request supplied.', null, null));
            return responses;
        }

        for (Request request : requests) {
            responses.add(handleRequest(request));
        }

        return responses;
    }

    private static Response handleRequest(Request request) {
        List<String> details = new List<String>();

        try {
            if (request == null || String.isBlank(request.objectConfigJson)) {
                return buildResponse(false, 'objectConfigJson is required.', null, details);
            }

            ObjectConfig config = (ObjectConfig) JSON.deserialize(request.objectConfigJson, ObjectConfig.class);
            validateObjectConfig(config);

            ToolingResult objectResult = createCustomObject(config);
            details.add('CustomObject ' + config.objectApiName + ': HTTP ' + objectResult.statusCode + ' ' + objectResult.body);

            if (!objectResult.isSuccess()) {
                return buildResponse(false, 'Failed to create CustomObject.', config.objectApiName, details);
            }

            if (config.fields != null) {
                for (FieldConfig field : config.fields) {
                    validateFieldConfig(field);
                    ToolingResult fieldResult = createCustomField(config.objectApiName, field);
                    details.add('CustomField ' + field.fieldApiName + ': HTTP ' + fieldResult.statusCode + ' ' + fieldResult.body);

                    if (!fieldResult.isSuccess()) {
                        return buildResponse(false, 'Failed to create CustomField ' + field.fieldApiName + '.', config.objectApiName, details);
                    }
                }
            }

            return buildResponse(true, 'Custom object and fields created successfully.', config.objectApiName, details);
        } catch (Exception ex) {
            return buildResponse(false, ex.getMessage(), null, details);
        }
    }

    private static ToolingResult createCustomObject(ObjectConfig config) {
        Map<String, Object> metadata = new Map<String, Object>{
            'label' => config.label,
            'pluralLabel' => String.isBlank(config.pluralLabel) ? config.label + 's' : config.pluralLabel,
            'description' => config.description,
            'sharingModel' => String.isBlank(config.sharingModel) ? 'ReadWrite' : config.sharingModel,
            'deploymentStatus' => String.isBlank(config.deploymentStatus) ? 'Deployed' : config.deploymentStatus,
            'nameField' => new Map<String, Object>{
                'type' => 'Text',
                'label' => String.isBlank(config.nameFieldLabel) ? config.label + ' Name' : config.nameFieldLabel
            }
        };

        Map<String, Object> payload = new Map<String, Object>{
            'FullName' => config.objectApiName,
            'Metadata' => metadata
        };

        return postTooling('/tooling/sobjects/CustomObject', payload);
    }

    private static ToolingResult createCustomField(String objectApiName, FieldConfig field) {
        Map<String, Object> metadata = new Map<String, Object>{
            'label' => field.label,
            'type' => normalizeFieldType(field.type),
            'description' => field.description,
            'required' => field.required == true
        };

        String normalizedType = normalizeFieldType(field.type);

        if (normalizedType == 'Text') {
            metadata.put('length', field.length == null ? 255 : field.length);
        } else if (normalizedType == 'LongTextArea') {
            metadata.put('length', field.length == null ? 32768 : field.length);
            metadata.put('visibleLines', field.visibleLines == null ? 5 : field.visibleLines);
        } else if (normalizedType == 'Number' || normalizedType == 'Currency') {
            metadata.put('precision', field.precision == null ? 18 : field.precision);
            metadata.put('scale', field.scale == null ? 2 : field.scale);
        } else if (normalizedType == 'Checkbox') {
            metadata.put('defaultValue', String.isBlank(field.defaultValue) ? 'false' : field.defaultValue);
        } else if (normalizedType == 'Picklist') {
            metadata.put('valueSet', buildPicklistValueSet(field.picklistValues));
        }

        Map<String, Object> payload = new Map<String, Object>{
            'FullName' => objectApiName + '.' + field.fieldApiName,
            'Metadata' => metadata
        };

        return postTooling('/tooling/sobjects/CustomField', payload);
    }

    private static Map<String, Object> buildPicklistValueSet(List<String> values) {
        if (values == null || values.isEmpty()) {
            throw new IllegalArgumentException('Picklist fields require picklistValues.');
        }

        List<Object> valueDefinitions = new List<Object>();
        for (String value : values) {
            if (String.isBlank(value)) {
                continue;
            }
            valueDefinitions.add(new Map<String, Object>{
                'fullName' => value,
                'default' => false,
                'label' => value
            });
        }

        if (valueDefinitions.isEmpty()) {
            throw new IllegalArgumentException('Picklist fields require at least one non-empty value.');
        }

        return new Map<String, Object>{
            'restricted' => true,
            'valueSetDefinition' => new Map<String, Object>{
                'sorted' => false,
                'value' => valueDefinitions
            }
        };
    }

    private static ToolingResult postTooling(String path, Map<String, Object> payload) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + NAMED_CREDENTIAL + '/services/data/' + API_VERSION + path);
        req.setMethod('POST');
        req.setTimeout(120000);
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(payload));

        HttpResponse res = new Http().send(req);
        return new ToolingResult(res.getStatusCode(), res.getBody());
    }

    private static void validateObjectConfig(ObjectConfig config) {
        if (config == null) {
            throw new IllegalArgumentException('Invalid objectConfigJson.');
        }
        validateApiName(config.objectApiName, 'Custom object API name');
        if (String.isBlank(config.label)) {
            throw new IllegalArgumentException('label is required.');
        }
    }

    private static void validateFieldConfig(FieldConfig field) {
        if (field == null) {
            throw new IllegalArgumentException('Field config cannot be null.');
        }
        validateApiName(field.fieldApiName, 'Custom field API name');
        if (String.isBlank(field.label)) {
            throw new IllegalArgumentException('Field label is required for ' + field.fieldApiName + '.');
        }
        normalizeFieldType(field.type);
    }

    private static void validateApiName(String value, String label) {
        if (String.isBlank(value)) {
            throw new IllegalArgumentException(label + ' is required.');
        }
        if (!value.endsWith('__c')) {
            throw new IllegalArgumentException(label + ' must end with __c: ' + value);
        }
        if (!Pattern.compile(API_NAME_REGEX).matcher(value).matches()) {
            throw new IllegalArgumentException(label + ' can contain only letters, numbers, and underscores, and must start with a letter: ' + value);
        }
    }

    private static String normalizeFieldType(String typeValue) {
        if (String.isBlank(typeValue)) {
            throw new IllegalArgumentException('Field type is required.');
        }

        String value = typeValue.trim();
        Set<String> supportedTypes = new Set<String>{
            'Text', 'LongTextArea', 'Number', 'Currency', 'Date', 'DateTime', 'Checkbox', 'Picklist'
        };

        for (String supportedType : supportedTypes) {
            if (supportedType.equalsIgnoreCase(value)) {
                return supportedType;
            }
        }

        throw new IllegalArgumentException('Unsupported field type: ' + typeValue);
    }

    private static Response buildResponse(Boolean success, String message, String objectApiName, List<String> details) {
        Response response = new Response();
        response.success = success;
        response.message = message;
        response.objectApiName = objectApiName;
        response.details = details == null ? null : String.join(details, ' | ');
        return response;
    }

    private class ToolingResult {
        Integer statusCode;
        String body;

        ToolingResult(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }

        Boolean isSuccess() {
            return statusCode >= 200 && statusCode < 300;
        }
    }
}