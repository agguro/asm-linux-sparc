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

#ifndef UPNP_TV_DEVICE_H
#define UPNP_TV_DEVICE_H

#include <stdio.h>
#include <signal.h>

#ifdef __cplusplus
extern "C" {
#endif

#include "ithread.h"
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include "upnp.h"
#include "sample_util.h"

//Power constants
#define POWER_ON 1
#define POWER_OFF 0

//Number of services.
#define TV_SERVICE_SERVCOUNT  1

//Index of control service
#define TV_SERVICE_CONTROL    0

//Number of control variables
#define TV_CONTROL_VARCOUNT   1

//Index of power variable
#define TV_CONTROL_POWER      0

//Max value length
#define TV_MAX_VAL_LEN 5

//Max actions
#define TV_MAXACTIONS 12

/* This should be the maximum VARCOUNT from above */
#define TV_MAXVARS 4


extern char TvDeviceType[];

extern char *TvServiceType[];



/******************************************************************************
 * upnp_action
 *
 * Description: 
 *       Prototype for all actions. For each action that a service 
 *       implements, there is a corresponding function with this prototype.
 *       Pointers to these functions, along with action names, are stored
 *       in the service table. When an action request comes in the action
 *       name is matched, and the appropriate function is called.
 *       Each function returns UPNP_E_SUCCESS, on success, and a nonzero 
 *       error code on failure.
 *
 * Parameters:
 *
 *    IXML_Document * request - document of action request
 *    IXML_Document **out - action result
 *    char **errorString - errorString (in case action was unsuccessful)
 *
 *****************************************************************************/

typedef int (*upnp_action) (IXML_Document *request, IXML_Document **out, 
			    char **errorString);

/* Structure for storing Tv Service
   identifiers and state table */
struct TvService {
  
  char UDN[NAME_SIZE]; /* Universally Unique Device Name */
  char ServiceId[NAME_SIZE];
  char ServiceType[NAME_SIZE];
  char *VariableName[TV_MAXVARS]; 
  char *VariableStrVal[TV_MAXVARS];
  char *ActionNames[TV_MAXACTIONS];
  upnp_action actions[TV_MAXACTIONS];
  unsigned int  VariableCount;
};

//Array of service structures
extern struct TvService tv_service_table[];

//Device handle returned from sdk
extern UpnpDevice_Handle device_handle;


/* Mutex for protecting the global state table data
   in a multi-threaded, asynchronous environment.
   All functions should lock this mutex before reading
   or writing the state table data. */
extern ithread_mutex_t TVDevMutex;



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
int SetActionTable(int serviceType, struct TvService * out);

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
int TvDeviceStateTableInit(char*);


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
int TvDeviceHandleSubscriptionRequest(struct Upnp_Subscription_Request *);

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
int TvDeviceHandleGetVarRequest(struct Upnp_State_Var_Request *);

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
int TvDeviceHandleActionRequest(struct Upnp_Action_Request *);

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
int TvDeviceCallbackEventHandler(Upnp_EventType, void*, void*);

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
int TvDeviceSetServiceTableVar(unsigned int, unsigned int, char*);

//Control Service Actions

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
int TvDevicePowerOn(IN IXML_Document * in, OUT IXML_Document **out, 
		    OUT char **errorString);

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
int TvDevicePowerOff(IN IXML_Document *in, OUT IXML_Document **out, 
		     OUT char **errorString);

int TvDeviceStart(char * ip_address, unsigned short port,char * desc_doc_name,
				  char *web_dir_path, print_string pfun);
int TvDeviceStop();

#ifdef __cplusplus
}
#endif

#endif
