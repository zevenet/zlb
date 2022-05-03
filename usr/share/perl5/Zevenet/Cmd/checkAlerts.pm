#!/usr/bin/perl
###############################################################################
#
#    Zevenet Software License
#    This file is part of the Zevenet Load Balancer software package.
#
#    Copyright (C) 2014-today ZEVENET SL, Sevilla (Spain)
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU Affero General Public License as
#    published by the Free Software Foundation, either version 3 of the
#    License, or any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU Affero General Public License for more details.
#
#    You should have received a copy of the GNU Affero General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
###############################################################################

if ( eval { require Zevenet::ELoad; } )
{
	$eload = 1;
}

unless ( $eload )
{
	&zenlog( "Alert functions are only for EE", "error", "notif" );
	exit 1;
}

# check if notifications are activated
my $status = &eload(
					 module => "Zevenet::Notify",
					 func   => "getNotifData",
					 args   => ['alerts', 'Notifications', 'Status'],
);

exit 1 if $status eq "off";

# license notification
my $status = &eload(
					 module => "Zevenet::Notify",
					 func   => "getNotifData",
					 args   => ['alerts', 'License', 'Status']
);
if ( $status eq 'on' )
{

	my $alert = &eload(
						module => "Zevenet::Notification::Alert",
						func   => "getAlert",
						args   => ["License"]
	);
	if ( $alert )
	{
		&logAndRunBG(
			"/usr/local/zevenet/bin/sendNotification sendNotification License \"$alert\"" );
	}
}

# certificate notification
my $status = &eload(
					 module => "Zevenet::Notify",
					 func   => "getNotifData",
					 args   => ['alerts', 'Certificate', 'Status']
);
if ( $status eq 'on' )
{
	my $alert = &eload(
						module => "Zevenet::Notification::Alert",
						func   => "getAlert",
						args   => ["Certificate"]
	);
	if ( $alert )
	{
		&logAndRunBG(
			"/usr/local/zevenet/bin/sendNotification sendNotification Certificate \"$alert\""
		);
	}
}

# cluster notification
my $status = &eload(
					 module => "Zevenet::Notify",
					 func   => "getNotifData",
					 args   => ['alerts', 'Cluster', 'Status']
);
if ( $status eq 'on' )
{
	my $alert = &eload(
						module => "Zevenet::Notification::Alert",
						func   => "getAlert",
						args   => ["Cluster"]
	);
	if ( $alert )
	{
		&logAndRunBG(
			"/usr/local/zevenet/bin/sendNotification sendNotification Cluster \"$alert\"" );
	}
}

# package notification
my $status = &eload(
					 module => "Zevenet::Notify",
					 func   => "getNotifData",
					 args   => ['alerts', 'Package', 'Status']
);
if ( $status eq 'on' )
{
	my $alert = &eload(
						module => "Zevenet::Notification::Alert",
						func   => "getAlert",
						args   => ["Package"]
	);
	if ( $alert )
	{
		&logAndRunBG(
			"/usr/local/zevenet/bin/sendNotification sendNotification Package \"$alert\"" );
	}
}

1;
