///////////////////////////////////////////////////////////////////////////
//
// Copyright (c) 2000-2003 Intel Corporation 
// All rights reserved. 
//
// Redistribution and use in source and binary forms, with or without 
// modification, are permitted provided that the following conditions are met: 
//
// * Redistributions of source code must retain the above copyright notice, 
// this list of conditions and the following disclaimer. 
// * Redistributions in binary form must reproduce the above copyright notice, 
// this list of conditions and the following disclaimer in the documentation 
// and/or other materials provided with the distribution. 
// * Neither name of Intel Corporation nor the names of its contributors 
// may be used to endorse or promote products derived from this software 
// without specific prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR 
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL INTEL OR 
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, 
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, 
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR 
// PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY 
// OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
// NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS 
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
///////////////////////////////////////////////////////////////////////////

#include "upnp_tv_device.h"

#define DEFAULT_WEB_DIR "/usr/share/upnp/web"

#define DESC_URL_SIZE 200

/*
   Device type for tv device 
 */
char TvDeviceType[] = "urn:schemas-upnp-org:device:Basic:1";

/*
   Service types for tv services
 */
char *TvServiceType[] = { "urn:schemas-upnp-org:service:nascontrol:1" };

/*
   Global arrays for storing Tv Control Service
   variable names, values, and defaults 
 */
char *tvc_varname[] = { "Power" };
char tvc_varval[TV_CONTROL_VARCOUNT][TV_MAX_VAL_LEN];
char *tvc_varval_def[] = { "1" };

/*
   The amount of time (in seconds) before advertisements
   will expire 
 */
int default_advr_expire = 300;

/*
   Global structure for storing the state table for this device 
 */
struct TvService tv_service_table[1];

/*
   Device handle supplied by UPnP SDK 
 */
UpnpDevice_Handle device_handle = -1;

/*
   Mutex for protecting the global state table data
   in a multi-threaded, asynchronous environment.
   All functions should lock this mutex before reading
   or writing the state table data. 
 */
ithread_mutex_t TVDevMutex;

//Power constants
#define POWER_ON 1
#define POWER_OFF 0

/******************************************************************************
 * SetServiceTable
 *
 * Description: 
 *       Initializes the service table for the specified service.
 *       Note that 
 *       knowledge of the service description is
 *       assumed. 
 * Parameters:
 *   int serviceType - one of TV_SERVICE_CONTROL or, TV_SERVICE_PICTURE
 *   const char * UDN - UDN of device containing service
 *   const char * serviceId - serviceId of service
 *   const char * serviceTypeS - service type (as specified in Description
 *                                             Document) 
 *   struct TvService *out - service containing table to be set.
 *
 *****************************************************************************/
int
SetServiceTable( IN int serviceType,
                 IN const char *UDN,
                 IN const char *serviceId,
                 IN const char *serviceTypeS,
                 INOUT struct TvService *out )
{
    unsigned int i = 0;

    strcpy( out->UDN, UDN );
    strcpy( out->ServiceId, serviceId );
    strcpy( out->ServiceType, serviceTypeS );

    switch ( serviceType ) {
        case TV_SERVICE_CONTROL:
            out->VariableCount = TV_CONTROL_VARCOUNT;
            for( i = 0;
                 i < tv_service_table[TV_SERVICE_CONTROL].VariableCount;
                 i++ ) {
                tv_service_table[TV_SERVICE_CONTROL].VariableName[i]
                    = tvc_varname[i];
                tv_service_table[TV_SERVICE_CONTROL].VariableStrVal[i]
                    = tvc_varval[i];
                strcpy( tv_service_table[TV_SERVICE_CONTROL].
                        VariableStrVal[i], tvc_varval_def[i] );
            }

            break;
        default:
            assert( 0 );
    }

    return SetActionTable( serviceType, out );

}

/******************************************************************************
 * SetActionTable
 *
 * Description: 
 *       Initializes the action table for the specified service.
 *       Note that 
 *       knowledge of the service description is
 *       assumed.  Action names are hardcoded.
 * Parameters:
 *   int serviceType - one of TV_SERVICE_CONTROL or, TV_SERVICE_PICTURE
 *   struct TvService *out - service containing action table to set.
 *
 *****************************************************************************/
int
SetActionTable( IN int serviceType,
                INOUT struct TvService *out )
{
    if( serviceType == TV_SERVICE_CONTROL ) {
        out->ActionNames[0] = "PowerOn";
        out->actions[0] = TvDevicePowerOn;
        out->ActionNames[1] = "PowerOff";
        out->actions[1] = TvDevicePowerOff;
        out->ActionNames[2] = NULL;
        return 1;
    }

    return 0;
}

/******************************************************************************
 * TvDeviceStateTableInit
 *
 * Description: 
 *       Initialize the device state table for 
 * 	 this TvDevice, pulling identifier info
 *       from the description Document.  Note that 
 *       knowledge of the service description is
 *       assumed.  State table variables and default
 *       values are currently hardcoded in this file
 *       rather than being read from service description
 *       documents.
 *
 * Parameters:
 *   DescDocURL -- The description document URL
 *
 *****************************************************************************/
int
TvDeviceStateTableInit( IN char *DescDocURL )
{
    IXML_Document *DescDoc = NULL;
    int ret = UPNP_E_SUCCESS;
    char *servid_ctrl = NULL,
     *evnturl_ctrl = NULL,
     *ctrlurl_ctrl = NULL;
    char *servid_pict = NULL,
     *evnturl_pict = NULL,
     *ctrlurl_pict = NULL;
    char *udn = NULL;

    //Download description document
    if( UpnpDownloadXmlDoc( DescDocURL, &DescDoc ) != UPNP_E_SUCCESS ) {
        SampleUtil_Print( "TvDeviceStateTableInit -- Error Parsing %s\n",
                          DescDocURL );
        ret = UPNP_E_INVALID_DESC;
        goto error_handler;
    }

    udn = SampleUtil_GetFirstDocumentItem( DescDoc, "UDN" );

    /*
       Find the Tv Control Service identifiers 
     */
    if( !SampleUtil_FindAndParseService( DescDoc, DescDocURL,
                                         TvServiceType[TV_SERVICE_CONTROL],
                                         &servid_ctrl, &evnturl_ctrl,
                                         &ctrlurl_ctrl ) ) {
        SampleUtil_Print( "TvDeviceStateTableInit -- Error: Could not find"
                          " Service: %s\n",
                          TvServiceType[TV_SERVICE_CONTROL] );

        ret = UPNP_E_INVALID_DESC;
        goto error_handler;
    }

    //set control service table
    SetServiceTable( TV_SERVICE_CONTROL, udn, servid_ctrl,
                     TvServiceType[TV_SERVICE_CONTROL],
                     &tv_service_table[TV_SERVICE_CONTROL] );

  error_handler:

    //clean up
    if( udn )
        free( udn );
    if( servid_ctrl )
        free( servid_ctrl );
    if( evnturl_ctrl )
        free( evnturl_ctrl );
    if( ctrlurl_ctrl )
        free( ctrlurl_ctrl );
    if( servid_pict )
        free( servid_pict );
    if( evnturl_pict )
        free( evnturl_pict );
    if( ctrlurl_pict )
        free( ctrlurl_pict );
    if( DescDoc )
        ixmlDocument_free( DescDoc );

    return ( ret );
}

/******************************************************************************
 * TvDeviceHandleSubscriptionRequest
 *
 * Description: 
 *       Called during a subscription request callback.  If the
 *       subscription request is for this device and either its
 *       control service or picture service, then accept it.
 *
 * Parameters:
 *   sr_event -- The subscription request event structure
 *
 *****************************************************************************/
int
TvDeviceHandleSubscriptionRequest( IN struct Upnp_Subscription_Request
                                   *sr_event )
{
    unsigned int i = 0;         //,j=0;

    // IXML_Document *PropSet=NULL;

    //lock state mutex
    ithread_mutex_lock( &TVDevMutex );

    for( i = 0; i < TV_SERVICE_SERVCOUNT; i++ ) {
        if( ( strcmp( sr_event->UDN, tv_service_table[i].UDN ) == 0 ) &&
            ( strcmp( sr_event->ServiceId, tv_service_table[i].ServiceId )
              == 0 ) ) {

            /*
               PropSet = NULL;

               for (j=0; j< tv_service_table[i].VariableCount; j++)
               {
               //add each variable to the property set
               //for initial state dump
               UpnpAddToPropertySet(&PropSet, 
               tv_service_table[i].VariableName[j],
               tv_service_table[i].VariableStrVal[j]);
               }

               //dump initial state 
               UpnpAcceptSubscriptionExt(device_handle, sr_event->UDN, 
               sr_event->ServiceId,
               PropSet,sr_event->Sid);
               //free document
               Document_free(PropSet);

             */

            UpnpAcceptSubscription( device_handle,
                                    sr_event->UDN,
                                    sr_event->ServiceId,
                                    ( const char ** )tv_service_table[i].
                                    VariableName,
                                    ( const char ** )tv_service_table[i].
                                    VariableStrVal,
                                    tv_service_table[i].VariableCount,
                                    sr_event->Sid );

        }
    }

    ithread_mutex_unlock( &TVDevMutex );

    return ( 1 );
}

/******************************************************************************
 * TvDeviceHandleGetVarRequest
 *
 * Description: 
 *       Called during a get variable request callback.  If the
 *       request is for this device and either its control service
 *       or picture service, then respond with the variable value.
 *
 * Parameters:
 *   cgv_event -- The control get variable request event structure
 *
 *****************************************************************************/
int
TvDeviceHandleGetVarRequest( INOUT struct Upnp_State_Var_Request
                             *cgv_event )
{
    unsigned int i = 0,
      j = 0;
    int getvar_succeeded = 0;

    cgv_event->CurrentVal = NULL;

    ithread_mutex_lock( &TVDevMutex );

    for( i = 0; i < TV_SERVICE_SERVCOUNT; i++ ) {
        //check udn and service id
        if( ( strcmp( cgv_event->DevUDN, tv_service_table[i].UDN ) == 0 )
            &&
            ( strcmp( cgv_event->ServiceID, tv_service_table[i].ServiceId )
              == 0 ) ) {
            //check variable name
            for( j = 0; j < tv_service_table[i].VariableCount; j++ ) {
                if( strcmp( cgv_event->StateVarName,
                            tv_service_table[i].VariableName[j] ) == 0 ) {
                    getvar_succeeded = 1;
                    cgv_event->CurrentVal =
                        ixmlCloneDOMString( tv_service_table[i].
                                            VariableStrVal[j] );
                    break;
                }
            }
        }
    }

    if( getvar_succeeded ) {
        cgv_event->ErrCode = UPNP_E_SUCCESS;
    } else {
        SampleUtil_Print
            ( "Error in UPNP_CONTROL_GET_VAR_REQUEST callback:\n" );
        SampleUtil_Print( "   Unknown variable name = %s\n",
                          cgv_event->StateVarName );
        cgv_event->ErrCode = 404;
        strcpy( cgv_event->ErrStr, "Invalid Variable" );
    }

    ithread_mutex_unlock( &TVDevMutex );

    return ( cgv_event->ErrCode == UPNP_E_SUCCESS );
}

/******************************************************************************
 * TvDeviceHandleActionRequest
 *
 * Description: 
 *       Called during an action request callback.  If the
 *       request is for this device and either its control service
 *       or picture service, then perform the action and respond.
 *
 * Parameters:
 *   ca_event -- The control action request event structure
 *
 *****************************************************************************/
int
TvDeviceHandleActionRequest( INOUT struct Upnp_Action_Request *ca_event )
{

    /*
       Defaults if action not found 
     */
    int action_found = 0;
    int i = 0;
    int service = -1;
    int retCode = 0;
    char *errorString = NULL;

    ca_event->ErrCode = 0;
    ca_event->ActionResult = NULL;

    if( ( strcmp( ca_event->DevUDN,
                  tv_service_table[TV_SERVICE_CONTROL].UDN ) == 0 ) &&
        ( strcmp
          ( ca_event->ServiceID,
            tv_service_table[TV_SERVICE_CONTROL].ServiceId ) == 0 ) ) {
        /*
           Request for action in the TvDevice Control Service 
         */
        service = TV_SERVICE_CONTROL;
    }
    //Find and call appropriate procedure based on action name
    //Each action name has an associated procedure stored in the
    //service table. These are set at initialization.

    for( i = 0; ( ( i < TV_MAXACTIONS ) &&
                  ( tv_service_table[service].ActionNames[i] != NULL ) );
         i++ ) {

        if( !strcmp( ca_event->ActionName,
                     tv_service_table[service].ActionNames[i] ) ) {

            if( ( !strcmp( tv_service_table[TV_SERVICE_CONTROL].
                           VariableStrVal[TV_CONTROL_POWER], "1" ) )
                || ( !strcmp( ca_event->ActionName, "PowerOn" ) ) ) {
                retCode =
                    tv_service_table[service].actions[i] ( ca_event->
                                                           ActionRequest,
                                                           &ca_event->
                                                           ActionResult,
                                                           &errorString );
            } else {
                errorString = "Power is Off";
                retCode = UPNP_E_INTERNAL_ERROR;
            }
            action_found = 1;
            break;
        }
    }

    if( !action_found ) {
        ca_event->ActionResult = NULL;
        strcpy( ca_event->ErrStr, "Invalid Action" );
        ca_event->ErrCode = 401;
    } else {
        if( retCode == UPNP_E_SUCCESS ) {
            ca_event->ErrCode = UPNP_E_SUCCESS;
        } else {
            //copy the error string 
            strcpy( ca_event->ErrStr, errorString );
            switch ( retCode ) {
                case UPNP_E_INVALID_PARAM:
                    {
                        ca_event->ErrCode = 402;
                        break;
                    }
                case UPNP_E_INTERNAL_ERROR:
                default:
                    {
                        ca_event->ErrCode = 501;
                        break;
                    }

            }
        }
    }

    return ( ca_event->ErrCode );
}

/******************************************************************************
 * TvDeviceSetServiceTableVar
 *
 * Description: 
 *       Update the TvDevice service state table, and notify all subscribed 
 *       control points of the updated state.  Note that since this function
 *       blocks on the mutex TVDevMutex, to avoid a hang this function should 
 *       not be called within any other function that currently has this mutex 
 *       locked.
 *
 * Parameters:
 *   service -- The service number (TV_SERVICE_CONTROL or TV_SERVICE_PICTURE)
 *   variable -- The variable number (TV_CONTROL_POWER, TV_CONTROL_CHANNEL,
 *                   TV_CONTROL_VOLUME, TV_PICTURE_COLOR, TV_PICTURE_TINT,
 *                   TV_PICTURE_CONTRAST, or TV_PICTURE_BRIGHTNESS)
 *   value -- The string representation of the new value
 *
 *****************************************************************************/
int
TvDeviceSetServiceTableVar( IN unsigned int service,
                            IN unsigned int variable,
                            IN char *value )
{
    //IXML_Document  *PropSet= NULL;

    if( ( service >= TV_SERVICE_SERVCOUNT )
        || ( variable >= tv_service_table[service].VariableCount )
        || ( strlen( value ) >= TV_MAX_VAL_LEN ) ) {
        return ( 0 );
    }

    ithread_mutex_lock( &TVDevMutex );

    strcpy( tv_service_table[service].VariableStrVal[variable], value );

    /*
       //Using utility api
       PropSet= UpnpCreatePropertySet(1,tv_service_table[service].
       VariableName[variable], 
       tv_service_table[service].
       VariableStrVal[variable]);

       UpnpNotifyExt(device_handle, tv_service_table[service].UDN, 
       tv_service_table[service].ServiceId,PropSet);

       //Free created property set
       Document_free(PropSet);
     */

    UpnpNotify( device_handle,
                tv_service_table[service].UDN,
                tv_service_table[service].ServiceId,
                ( const char ** )&tv_service_table[service].
                VariableName[variable],
                ( const char ** )&tv_service_table[service].
                VariableStrVal[variable], 1 );

    ithread_mutex_unlock( &TVDevMutex );

    return ( 1 );

}

/******************************************************************************
 * TvDeviceSetPower
 *
 * Description: 
 *       Turn the power on/off, update the TvDevice control service
 *       state table, and notify all subscribed control points of the
 *       updated state.
 *
 * Parameters:
 *   on -- If 1, turn power on.  If 0, turn power off.
 *
 *****************************************************************************/
int
TvDeviceSetPower( IN int on )
{
    char value[TV_MAX_VAL_LEN];
    int ret = 0;

    if( on != POWER_ON && on != POWER_OFF ) {
        SampleUtil_Print( "error: can't set power to value %d\n", on );
        return ( 0 );
    }

    /*
       Vendor-specific code to turn the power on/off goes here 
     */

    sprintf( value, "%d", on );
    ret = TvDeviceSetServiceTableVar( TV_SERVICE_CONTROL, TV_CONTROL_POWER,
                                      value );

    return ( ret );
}

/******************************************************************************
 * TvDevicePowerOn
 *
 * Description: 
 *       Turn the power on.
 *
 * Parameters:
 *
 *    IXML_Document * in - document of action request
 *    IXML_Document **out - action result
 *    char **errorString - errorString (in case action was unsuccessful)
 *
 *****************************************************************************/
int
TvDevicePowerOn( IN IXML_Document * in,
                 OUT IXML_Document ** out,
                 OUT char **errorString )
{
    ( *out ) = NULL;
    ( *errorString ) = NULL;

    if( TvDeviceSetPower( POWER_ON ) ) {
        //create a response

        if( UpnpAddToActionResponse( out, "PowerOn",
                                     TvServiceType[TV_SERVICE_CONTROL],
                                     "Power", "1" ) != UPNP_E_SUCCESS ) {
            ( *out ) = NULL;
            ( *errorString ) = "Internal Error";
            return UPNP_E_INTERNAL_ERROR;
        }
        return UPNP_E_SUCCESS;
    } else {
        ( *errorString ) = "Internal Error";
        return UPNP_E_INTERNAL_ERROR;
    }

}

/******************************************************************************
 * TvDevicePowerOff
 *
 * Description: 
 *       Turn the power off.
 *
 * Parameters:
 *    
 *    IXML_Document * in - document of action request
 *    IXML_Document **out - action result
 *    char **errorString - errorString (in case action was unsuccessful)
 *
 *****************************************************************************/
int
TvDevicePowerOff( IN IXML_Document * in,
                  OUT IXML_Document ** out,
                  OUT char **errorString )
{
    ( *out ) = NULL;
    ( *errorString ) = NULL;
    if( TvDeviceSetPower( POWER_OFF ) ) {
        //create a response

        if( UpnpAddToActionResponse( out, "PowerOff",
                                     TvServiceType[TV_SERVICE_CONTROL],
                                     "Power", "0" ) != UPNP_E_SUCCESS ) {
            ( *out ) = NULL;
            ( *errorString ) = "Internal Error";
            return UPNP_E_INTERNAL_ERROR;
        }

        return UPNP_E_SUCCESS;
    }

    ( *errorString ) = "Internal Error";
    return UPNP_E_INTERNAL_ERROR;
}

/******************************************************************************
 * TvDeviceCallbackEventHandler
 *
 * Description: 
 *       The callback handler registered with the SDK while registering
 *       root device.  Dispatches the request to the appropriate procedure
 *       based on the value of EventType. The four requests handled by the 
 *       device are: 
 *                   1) Event Subscription requests.  
 *                   2) Get Variable requests. 
 *                   3) Action requests.
 *
 * Parameters:
 *
 *   EventType -- The type of callback event
 *   Event -- Data structure containing event data
 *   Cookie -- Optional data specified during callback registration
 *
 *****************************************************************************/
int
TvDeviceCallbackEventHandler( Upnp_EventType EventType,
                              void *Event,
                              void *Cookie )
{

    switch ( EventType ) {
/*
        case UPNP_EVENT_SUBSCRIPTION_REQUEST:

            TvDeviceHandleSubscriptionRequest( ( struct
                                                 Upnp_Subscription_Request
                                                 * )Event );
            break;

        case UPNP_CONTROL_GET_VAR_REQUEST:
            TvDeviceHandleGetVarRequest( ( struct Upnp_State_Var_Request
                                           * )Event );
            break;

        case UPNP_CONTROL_ACTION_REQUEST:
            TvDeviceHandleActionRequest( ( struct Upnp_Action_Request * )
                                         Event );
            break;
*/
            /*
               ignore these cases, since this is not a control point 
             */
	case UPNP_EVENT_SUBSCRIPTION_REQUEST:
	case UPNP_CONTROL_GET_VAR_REQUEST:
	case UPNP_CONTROL_ACTION_REQUEST:
        case UPNP_DISCOVERY_ADVERTISEMENT_ALIVE:
        case UPNP_DISCOVERY_SEARCH_RESULT:
        case UPNP_DISCOVERY_SEARCH_TIMEOUT:
        case UPNP_DISCOVERY_ADVERTISEMENT_BYEBYE:
        case UPNP_CONTROL_ACTION_COMPLETE:
        case UPNP_CONTROL_GET_VAR_COMPLETE:
        case UPNP_EVENT_RECEIVED:
        case UPNP_EVENT_RENEWAL_COMPLETE:
        case UPNP_EVENT_SUBSCRIBE_COMPLETE:
        case UPNP_EVENT_UNSUBSCRIBE_COMPLETE:
            break;

        default:
            SampleUtil_Print
                ( "Error in TvDeviceCallbackEventHandler: unknown event type %d\n",
                  EventType );
    }

    /*
       Print a summary of the event received 
     */
    SampleUtil_PrintEvent( EventType, Event );

    return ( 0 );
}

/******************************************************************************
 * TvDeviceStop
 *
 * Description: 
 *       Stops the device. Uninitializes the sdk. 
 *
 * Parameters:
 *
 *****************************************************************************/
int
TvDeviceStop(  )
{
    UpnpUnRegisterRootDevice( device_handle );
    UpnpFinish(  );
    SampleUtil_Finish(  );
    ithread_mutex_destroy( &TVDevMutex );
    return UPNP_E_SUCCESS;
}

/******************************************************************************
 * TvDeviceStart
 *
 * Description: 
 *      Initializes the UPnP Sdk, registers the device, and sends out 
 *      advertisements.  
 *
 * Parameters:
 *
 *   ip_address - ip address to initialize the sdk (may be NULL)
 *                if null, then the first non null loopback address is used.
 *   port       - port number to initialize the sdk (may be 0)
 *                if zero, then a random number is used.
 *   desc_doc_name - name of description document.
 *                   may be NULL. Default is tvdevicedesc.xml
 *   web_dir_path  - path of web directory.
 *                   may be NULL. Default is ./web (for Linux) or ../tvdevice/web
 *                   for windows.
 *   pfun          - print function to use.  
 *
 *****************************************************************************/
int
TvDeviceStart( char *ip_address,
               unsigned short port,
               char *desc_doc_name,
               char *web_dir_path,
               print_string pfun )
{
    int ret = UPNP_E_SUCCESS;

    char desc_doc_url[DESC_URL_SIZE];

    ithread_mutex_init( &TVDevMutex, NULL );

    SampleUtil_Initialize( pfun );

    SampleUtil_Print
        ( "Initializing UPnP Sdk with \n \t ipaddress = %s port = %d\n",
          ip_address, port );

    if( ( ret = UpnpInit( ip_address, port ) ) != UPNP_E_SUCCESS ) {
        SampleUtil_Print( "Error with UpnpInit -- %d\n", ret );
        UpnpFinish(  );
        return ret;
    }

    if( ip_address == NULL ) {
        ip_address = UpnpGetServerIpAddress(  );
    }

    if( port == 0 ) {
        port = UpnpGetServerPort(  );
    }

    SampleUtil_Print( "UPnP Initialized\n \t ipaddress= %s port = %d\n",
                      ip_address, port );

    if( desc_doc_name == NULL )
        desc_doc_name = "nasdevicedesc.xml";

    if( web_dir_path == NULL )
        web_dir_path = DEFAULT_WEB_DIR;

    snprintf( desc_doc_url, DESC_URL_SIZE, "http://%s:%d/%s", ip_address,
              port, desc_doc_name );

    SampleUtil_Print( "Specifying the webserver root directory -- %s\n",
                      web_dir_path );
    if( ( ret =
          UpnpSetWebServerRootDir( web_dir_path ) ) != UPNP_E_SUCCESS ) {
        SampleUtil_Print
            ( "Error specifying webserver root directory -- %s: %d\n",
              web_dir_path, ret );
        UpnpFinish(  );
        return ret;
    }

    SampleUtil_Print
        ( "Registering the RootDevice\n\t with desc_doc_url: %s\n",
          desc_doc_url );

    if( ( ret = UpnpRegisterRootDevice( desc_doc_url,
                                        TvDeviceCallbackEventHandler,
                                        &device_handle, &device_handle ) )
        != UPNP_E_SUCCESS ) {
        SampleUtil_Print( "Error registering the rootdevice : %d\n", ret );
        UpnpFinish(  );
        return ret;
    } else {
        SampleUtil_Print( "RootDevice Registered\n" );

        SampleUtil_Print( "Initializing State Table\n" );
        TvDeviceStateTableInit( desc_doc_url );
        SampleUtil_Print( "State Table Initialized\n" );

        if( ( ret =
              UpnpSendAdvertisement( device_handle, default_advr_expire ) )
            != UPNP_E_SUCCESS ) {
            SampleUtil_Print( "Error sending advertisements : %d\n", ret );
            UpnpFinish(  );
            return ret;
        }

        SampleUtil_Print( "Advertisements Sent\n" );
    }
    return UPNP_E_SUCCESS;
}
