This doc define the JSON struct used to validate the POST and PUT API parameters.

## Repo
This repository has a **build.pl** script in order to create the json files from some json templates.
The json templates will be expanded with regexp define in the **regexp** file. This macros are
perl variables *$farmname*.

## Validation definition

Some considerations in API parameters are:
	- Almost 1 parameter must be sent in API call
	- All required parameters must exist in the API call
	- Every parameter sent in API call should be defined in its JSON API definition

### json struct example:

```
farm-http-edit file:
{
	"method" : "PUT",
	"url" : "/farm/<farmname>",
	"action" : "edit",
    "description" : "It creates a HTTP farm in the load balancer",
	"params" : {
		"profile" : {
					   'required'  : 'true',
					   'non_blank' : 'true',
					   'values'    : ['http', 'gslb', 'l4xnat', 'datalink'],
		},
		...
	}
}
```

### JSON

Field        | Description
------------ | -------------
method     |  Method for the API call. It can be PUT or POST
url | 	It is the URL for the API call. The string between '<>' is name of the parameter that must be used as ID in the call
action | It is a descriptible name for the action that will be executed. The possible values are: edit, create, move, set, clean...". Maybe it is useful for ZCLI
description | It is a brief description about the action that will be executed
params | It is a *params* object with the parameter names and its options. Each key is the parameter name

### params object:

The key is the parameter name and the options defines how the parameter has to be sent

```
	{
		parameter :
		{
			"required" 	: "true",
			"non_blank" : "true",
			"interval" 	: "1,65535"
			"exceptions"	: [ "zapi", "webgui", "root" ],
			"values" : ["priority", "weight"],
			"length" : 32,
			"regex"	: "/\w+,\d+/",
			"ref"	: "array|hash",
			"deprecated"	: "array|hash",
			"format_msg"	: "must have letters and digits",
			"depend_on": "type==remote && frequency==daily",
			"depend_on_msg": "if this parameter is configured, no one more is expected",
			"edition"	: "ee",
		},
		....
	}
```

Field        | Example | Description
------------ | ------------- | -------------
required 	| "true"  | The parameter is marked as mandatory if this option has the value "true"
non_blank  	| "true"  | The parameter can be accepted as empty string if this parameter has the vale "true"
interval 	| "1,65535"   | They are 2 integer values splitted by comma, the first is the initial valid value for the parameter and the end one is the last acceptable value. If some of the integers are omited, no limit is checked: ",10" no limit at beginning, "10," no limit at ending.
exceptions 	|  [ "zapi", "webgui", "root" ] | It is a list of parameters do not allowed for this parameter.
values  | ["priority", "weight"] | It is a list of possible values for a parameter. A value different of the list is not allowed. This parameter can be set in a ZAPI response if it has the value **????**
dyn_values	| "true" | If this parameter is **true**, the list of values depend on the load balancer configuration. The API will respond with the *values* option filled if a request without body is sent by the client.
length 	| 32 | It is the limit of the string length for the parameter.
regex 	| "/\w+,\d+/" | It is a regular expression that the parameter value must accomplish
ref 	| `"array|hash", "array|none"` | It defines if the parameter value can be an array or hash reference. Several values can be combined with the pipe "|" character. The possible values are: **array** to allow a list of values, **hash** to allow an object or **none** to a scalar (integer or strings) value.
format_msg 	| "must have letters and digits" | It is a description about the expected parameter format
description | "Virtual IP where the farm is receiving traffic." | Documentation of the parameter
edition | "ee" | This parameter shows the ZEVENET edition which implement this parameter, the values are: **ee** for Enterprise or **ce** for community. If this option is not defined, both edition support the parameter.
depend_on 	| `"param2<=3 && param1==defined, param4!=null"` | **(TBI)** It defines relation with other object parameters. Several conditions can be combined
depend_on_msg | "The link must be up at the moment of creating the new bonding"` | **(TBI)** It is a message in order to get further information about some requirement to this parameter.
deprecated"  | "true"  | It marks the parameter to be deleted in following versions.

## ZEVENET

The following parameters are added in the ZEVENET package and should be migrated/replaced

Field        | Example | Description
------------ | ------------- | -------------
function | \&validaIPv4 | The function of validating, the input parameter is the value of the argument. The function has to return 0 or 'false' when a error exists
valid_format | "farmname" |  the regex stored in Validate.pm file, it checks with the function getValidFormat. This should be replaced for the regex parameter and a macro: `"regex": '$farmname'`

