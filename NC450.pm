# ==========================================================================
#
# ZoneMinder TP-Link NC450 ONVIF IP Control Protocol Module, Date: 2019-04-29
# Converted for use with TP-Link NC450 Camera by Danijel Dobranovic
# Copyright (C) 2019 Danijel Dobranovic
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
# ==========================================================================
#
package ZoneMinder::Control::NC450;

use 5.006;
use strict;
use warnings;

require ZoneMinder::Base;
require ZoneMinder::Control;

our @ISA = qw(ZoneMinder::Control);

our %CamParams = ();

# ==========================================================================
#
# TP-Link NC450 IP Control Protocol
# This script sends ONVIF compliant commands and may work with other cameras
# that require authentication
#
# Developed and tested with IP camera:
# TP-Link NC450 2.0 firmware: 1.5.0 Build 181022 Rel.3A033D
#
# On ControlAddress use the format :
#   USERNAME:PASSWORD@ADDRESS:PORT
#   eg : admin:password@192.168.0.100:2020
#
# Use port 2020 by default for TP-Link NC450 camera
#
# Make sure and place a value in the Auto Stop Timeout field.
# Recommend starting with a value of 1 second, and adjust accordingly.
#
# ==========================================================================

use ZoneMinder::Logger qw(:all);
use ZoneMinder::Config qw(:all);

use Time::HiRes qw( usleep );

use MIME::Base64;
use Digest::SHA;
use DateTime;

use Encode qw(encode decode);

my ($username,$password,$host,$port);

sub open
{
    my $self = shift;

    $self->loadMonitor();
    #
    # Extract the username/password host/port from ControlAddress
    #
    if( $self->{Monitor}{ControlAddress} =~ /^([^:]+):([^@]+)@(.+)/ )
    { # user:pass@host...
      $username = $1;
      $password = $2;
      $host = $3;
    }
    elsif( $self->{Monitor}{ControlAddress} =~ /^([^@]+)@(.+)/ )
    { # user@host...
      $username = $1;
      $host = $2;
    }
    else { # Just a host
      $host = $self->{Monitor}{ControlAddress};
    }
    # Check if it is a host and port or just a host
    if( $host =~ /([^:]+):(.+)/ )
    {
      $host = $1;
      $port = $2;
    }
    else
    {
      $port = 80;
    }

    use LWP::UserAgent;
    $self->{ua} = LWP::UserAgent->new;
    $self->{ua}->agent( "ZoneMinder Control Agent/".ZoneMinder::Base::ZM_VERSION );

    $self->{state} = 'open';
}

sub printMsg
{
    my $self = shift;
    my $msg = shift;
    my $msg_len = length($msg);

    Debug( $msg."[".$msg_len."]" );
}

sub sendCmdReq
{
    my $self = shift;
    my $cmd = shift;
    my $msg = shift;
    my $content_type = shift;
    my $result = undef;

    #printMsg( $cmd, "Tx" );

    my $server_endpoint = "http://".$host.":".$port."/$cmd";
    my $req = HTTP::Request->new( POST => $server_endpoint );
    $req->header('content-type' => $content_type);
    $req->header('Host' => $host.":".$port);
    $req->header('content-length' => length($msg));
    $req->header('accept-encoding' => 'gzip, deflate');
    $req->header('connection' => 'close');
    $req->content($msg);

    my $res = $self->{ua}->request($req);

    return( $res );
}

sub sendCmd
{
    my $self = shift;
    my $result = undef;

    my $res = $self->sendCmdReq(@_);

    if ( $res->is_success ) {
        $result = !undef;
    } else {
        Error( "After sending command, camera returned the following error:'".$res->status_line()."'" );
    }
    return( $result );
}

sub soapEnvelope
{
    my $self = shift;
    my $commandMsg = shift;
    my $action = shift;

    my $nonce;
    my $in;

    for (0..15){$nonce .= chr(int(rand(254)));}
    $nonce .= chr(int(0));

    my $mydate = DateTime->now()->format_cldr("yyy-MM-dd'T'HH:mm:ss.000'Z'");

    my $sha = Digest::SHA->new(1);
    $sha->add($nonce.$mydate.$password);
    my $digest = encode_base64($sha->digest,"");

    my $msg ='<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope"><s:Header><Security s:mustUnderstand="1" xmlns="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><UsernameToken><Username>'.$username.'</Username><Password Type="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordDigest">'.$digest.'</Password><Nonce EncodingType="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-soap-message-security-1.0#Base64Binary">'.encode_base64($nonce,"").'</Nonce><Created xmlns="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">'.$mydate.'</Created></UsernameToken></Security></s:Header><s:Body xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">'.$commandMsg.'</s:Body></s:Envelope>';

    my $content_type = 'application/soap+xml; charset=utf-8; action="'.$action.'"';

    return ($msg, $content_type)
}

sub getCamParams
{
    my $self = shift;
    my $cmd = 'onvif/imaging';

    my $commandMsg = '<GetImagingSettings xmlns="http://www.onvif.org/ver20/imaging/wsdl"><VideoSourceToken>VideoSource0</VideoSourceToken></GetImagingSettings>';
    my $action = 'http://www.onvif.org/ver20/imaging/wsdl/GetImagingSettings';

    my ($msg, $content_type) = $self->soapEnvelope($commandMsg, $action);

    my $res = $self->sendCmdReq( $cmd, $msg, $content_type);

    if ( $res->is_success ) {
        my $content = $res->decoded_content;

        if ($content =~ /.*<tt:(Brightness)>(.+)<\/tt:Brightness>.*/) {
            $CamParams{$1} = $2;
        }
        if ($content =~ /.*<tt:(Contrast)>(.+)<\/tt:Contrast>.*/) {
            $CamParams{$1} = $2;
        }
    }
    else
    {
        Error( "Unable to retrieve camera image settings:'".$res->status_line()."'" );
    }
}

sub moveStop
{
    Info( "Move Stop" );
    my $self = shift;
    my $cmd = 'onvif/service';

    my $commandMsg = '<Stop xmlns="http://www.onvif.org/ver20/ptz/wsdl"><ProfileToken>profile1</ProfileToken><PanTilt>true</PanTilt><Zoom>false</Zoom></Stop>';
    my $action = 'http://www.onvif.org/ver20/ptz/wsdl/ContinuousMove';

    my ($msg, $content_type) = $self->soapEnvelope($commandMsg, $action);

    $self->sendCmd( $cmd, $msg, $content_type );
}

#This makes use of the ZoneMinder Auto Stop Timeout on the Control Tab
sub autoStop
{
    my $self = shift;
    my $autostop = shift;

    if( $autostop ) {
        usleep( $autostop );
        $self->moveStop();
    }
}

# Reboot camera
# Not working with NC450
sub reset
{
    Info( "Camera Reset" );
    my $self = shift;

    my $action = 'http://www.onvif.org/ver10/device/wsdl/SystemReboot';
    my $commandMsg = '<SystemReboot xmlns="http://www.onvif.org/ver10/device/wsdl"/>';
    my $cmd = '';

    my ($msg, $content_type) = $self->soapEnvelope($commandMsg, $action);

    $self->sendCmd( $cmd, $msg, $content_type );
}

#
# NC450 ONVIF move
#
sub moveXY
{
    Info("Move camera");
    my $self = shift;
    my $moveX = shift;
    my $moveY = shift;

    my $action = 'http://www.onvif.org/ver20/ptz/wsdl/ContinuousMove';
    my $commandMsg = '<ContinuousMove xmlns="http://www.onvif.org/ver20/ptz/wsdl"><ProfileToken>profile1</ProfileToken><Velocity><PanTilt x="'.$moveX.'" y="'.$moveY.'" xmlns="http://www.onvif.org/ver10/schema"/></Velocity></ContinuousMove>';
    my $cmd = 'onvif/service';

    my ($msg, $content_type) = $self->soapEnvelope($commandMsg, $action);

    $self->sendCmd( $cmd, $msg, $content_type );
    $self->autoStop( $self->{Monitor}->{AutoStopTimeout} );
}

sub moveTest
{
    Info("Move camera");
    my $self = shift;
    my $moveX = shift;
    my $moveY = shift;

    my $action = 'http://www.onvif.org/ver20/ptz/wsdl/ContinuousMove';
    my $commandMsg = '<ContinuousMove xmlns="http://www.onvif.org/ver20/ptz/wsdl"><ProfileToken>profile1</ProfileToken><Velocity><PanTilt x="'.$moveX.'" y="'.$moveY.'" xmlns="http://www.onvif.org/ver10/schema"/></Velocity></ContinuousMove>';
    my $cmd = 'onvif/service';

    my ($msg, $content_type) = $self->soapEnvelope($commandMsg, $action);

    print "\nCMD:\n",$cmd,"\n";
    print "\nMSG:\n",$msg,"\n";
    print "\nContent type:\n",$content_type,"\n";
}

sub moveConUp
{
    Info( "Move Up" );
    my $self = shift;

    $self->moveXY('0','0.5')
}

sub moveConDown
{
    Info( "Move Down" );
    my $self = shift;

    $self->moveXY('0','-0.5')
}

sub moveConLeft
{
    Info( "Move Left" );
    my $self = shift;

    $self->moveXY('-0.5','0')
}

sub moveConRight
{
    Info( "Move Right" );
    my $self = shift;

    $self->moveXY('0.5','0')
}

#Zoom In
sub zoomConTele
{
    Info( "Zoom Tele" );
    Error( "PTZ Command not implemented in control script." );
}

#Zoom Out
sub zoomConWide
{
    Info( "Zoom Wide" );
    Error( "PTZ Command not implemented in control script." );
}

sub moveConUpRight
{
    Info( "Move Diagonally Up Right" );
    my $self = shift;

    $self->moveXY('0.5','0.5')
}

sub moveConDownRight
{
    Info( "Move Diagonally Down Right" );
    my $self = shift;

    $self->moveXY('0.5','-0.5')
}

sub moveConUpLeft
{
    Info( "Move Diagonally Up Left" );
    my $self = shift;

    $self->moveXY('-0.5','0.5')
}

sub moveConDownLeft
{
    Info( "Move Diagonally Down Left" );
    my $self = shift;

    $self->moveXY('-0.5','-0.5')
}

sub presetHome
{
  Info( "Move Stop" );
  my $self = shift;
  my $cmd = 'onvif/service';

  my $commandMsg = '<GotoHomePosition xmlns="http://www.onvif.org/ver20/ptz/wsdl"><ProfileToken>profile1</ProfileToken></GotoHomePosition>';
  my $action = 'http://www.onvif.org/ver20/ptz/wsdl/GotoHomePosition';

  my ($msg, $content_type) = $self->soapEnvelope($commandMsg, $action);

  $self->sendCmd( $cmd, $msg, $content_type );
}

#Clear Camera Preset
#no feature on NC450
sub presetClear
{
    my $self = shift;
    my $params = shift;
    my $preset = $self->getParam( $params, 'preset' );
    Info( "Clear Preset $preset" );
    Error( "Clear Preset: command not implemented in control script." );
}

#Set Camera Preset
#no feature on NC450
sub presetSet
{
    my $self = shift;
    my $params = shift;
    my $preset = $self->getParam( $params, 'preset' );
    Info( "Set Preset $preset" );
    Error( "Set Preset: command not implemented in control script." );
}

#Recall Camera Preset
sub presetGoto
{
    my $self = shift;
    my $params = shift;
    my $preset = $self->getParam( $params, 'preset' );
    my $num = sprintf("%03d", $preset);
    $num=~ tr/ /0/;
    Info( "Goto Preset $preset" );
    Error( "Goto Preset: command not implemented in control script." );
}


sub irisAbs
{
    Info( "Iris $CamParams{'Brightness'}" );
    my $self = shift;
    my $params = shift;
    my $add = shift;

    $self->getCamParams() unless($CamParams{'Brightness'});
    my $step = $self->getParam( $params, 'step' );
    my $max = 100;
    my $min = 0;

    if ($add)
    {
      $CamParams{'Brightness'} += $step;
    }
    else
    {
      $CamParams{'Brightness'} -= $step;
    }
    $CamParams{'Brightness'} = $max if ($CamParams{'Brightness'} > $max);
    $CamParams{'Brightness'} = $min if ($CamParams{'Brightness'} < $min);

    my $cmd = 'onvif/imaging';
    my $action = 'http://www.onvif.org/ver20/imaging/wsdl/SetImagingSettings';
    my $commandMsg = '<SetImagingSettings xmlns="http://www.onvif.org/ver20/imaging/wsdl"><VideoSourceToken>VideoSource0</VideoSourceToken><ImagingSettings><Brightness xmlns="http://www.onvif.org/ver10/schema">'.$CamParams{'Brightness'}.'</Brightness></ImagingSettings><ForcePersistence>true</ForcePersistence></SetImagingSettings>';

    my ($msg, $content_type) = $self->soapEnvelope($commandMsg, $action);

    $self->sendCmd( $cmd, $msg, $content_type );
}

# Increase Brightness
sub irisAbsOpen
{
    my $self = shift;
    $self->irisAbs(@_,1)
}

# Decrease Brightness
sub irisAbsClose
{
    my $self = shift;
    $self->irisAbs(@_,0)
}

sub whiteAbs
{
    my $self = shift;

    my $params = shift;
    my $add = shift;

    $self->getCamParams() unless($CamParams{'Contrast'});
    my $step = $self->getParam( $params, 'step' );
    my $max = 100;
    my $min = 0;

    if ($add)
    {
      $CamParams{'Contrast'} += $step;
    }
    else
    {
      $CamParams{'Contrast'} -= $step;
    }
    $CamParams{'Contrast'} = $max if ($CamParams{'Contrast'} > $max);
    $CamParams{'Contrast'} = $min if ($CamParams{'Contrast'} < $min);

    my $cmd = 'onvif/imaging';
    my $action = 'http://www.onvif.org/ver20/imaging/wsdl/SetImagingSettings';
    my $commandMsg = '<SetImagingSettings xmlns="http://www.onvif.org/ver20/imaging/wsdl"><VideoSourceToken>VideoSource0</VideoSourceToken><ImagingSettings><Contrast xmlns="http://www.onvif.org/ver10/schema">'.$CamParams{'Contrast'}.'</Contrast></ImagingSettings><ForcePersistence>true</ForcePersistence></SetImagingSettings>';

    my ($msg, $content_type) = $self->soapEnvelope($commandMsg, $action);

    $self->sendCmd( $cmd, $msg, $content_type );
}

# Increase Contrast
sub whiteAbsIn
{
  Info( "Iris $CamParams{'Contrast'}" );
  my $self = shift;

  $self->whiteAbs(@_, 1);
}

# Decrease Contrast
sub whiteAbsOut
{
    Info( "Iris $CamParams{'Contrast'}" );
    my $self = shift;

    $self->whiteAbs(@_, 0);
}

1;
