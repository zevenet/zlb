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

use strict;

use Zevenet::Core;
use Zevenet::Log;
use Zevenet::Config;
use Zevenet::Validate;
use Zevenet::Debug;
use Zevenet::Netfilter;
use Zevenet::Net::Interface;
use Zevenet::FarmGuardian;
use Zevenet::Backup;
use Zevenet::RRD;
use Zevenet::SNMP;
use Zevenet::Stats;
use Zevenet::SystemInfo;
use Zevenet::System;
use Zevenet::Zapi;

require Zevenet::CGI if defined $ENV{ GATEWAY_INTERFACE };

1;
