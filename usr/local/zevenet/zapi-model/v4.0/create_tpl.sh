file="$1.json"

filepath="./tpl/$file"

echo -n '{
    "method" : "????",
    "url" : "???",
    "action" : "??????",
    "description" : "??????",
    "params" : {


	}
}
' >$filepath

echo -n '
my $params = &getZAPIModel( "'$file'" );
' >>$filepath

echo "created: $filepath"
