#!/usr/bin/perl
###############################################################################
#
#     Zevenet Software License
#     This file is part of the Zevenet software package.
#
#     Copyright (C) 2014 SOFINTEL IT ENGINEERING SL, Sevilla (Spain)
#
#     This library is free software; you can redistribute it and/or modify it
#     under the terms of the GNU Lesser General Public License as published
#     by the Free Software Foundation; either version 2.1 of the License, or 
#     (at your option) any later version.
#
#     This library is distributed in the hope that it will be useful, but 
#     WITHOUT ANY WARRANTY; without even the implied warranty of 
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser
#     General Public License for more details.
#
#     You should have received a copy of the GNU Lesser General Public License
#     along with this library; if not, write to the Free Software Foundation,
#     Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#
###############################################################################	


use CGI qw(:standard escapeHTML);
print "Content-type: text/html\n\n";

##REQUIRES
#require "help-content.cgi";


print "
<HTML>
<head>
<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\" />

<link type=\"text/css\" rel=\"stylesheet\" media=\"all\" href=\"css/base.css\" />
<link type=\"text/css\" rel=\"stylesheet\" media=\"all\" href=\"css/grid.css\" />
<title>Zen Logout</title></head>";

print "<BODY>";

print "<div id=\"header\">
	 <div class=\"header-top tr\">";

print "<br><br><br>";
print "<div id=\"page-header\"></div>

	 </div>
      </div>";


#print "<b>Upload Backup.</b>";
#print "<div id=\"page-header\"></div>";
print "<br>";
print "<br>";

print "<center>";
print "<strong>Good bye ZEVENET Master!</strong><br>";
print "<br><br>";
print "<strong><a href=\"../index.cgi\">Login</a></strong><br>";
print "</center>";

print "<br>";
print "</BODY>";
print "</HTML>"; 

