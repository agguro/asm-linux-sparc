/*  main.cc - this file is part of MediaTomb.
                                                                                
    Copyright (C) 2005 Gena Batyan <bgeradz@deadlock.dhs.org>,
                       Sergey Bostandzhyan <jin@deadlock.dhs.org>
                                                                                
    MediaTomb is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.
                                                                                
    MediaTomb is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
                                                                                
    You should have received a copy of the GNU General Public License
    along with MediaTomb; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/
#include <unistd.h>
#include <stdlib.h>
#include <fcntl.h>
#include "dnotify.h"
#include <signal.h>
#include "common.h"
#include "server.h"
#include "process.h"
#include <getopt.h>
#include "config_manager.h"
#include "content_manager.h"
#include "common.h"

#define OPTSTR "i:p:c:h"

using namespace zmm;

static unsigned long g_media_touched = 0;
static unsigned long g_server_shutdown = 0;

void handle_sighup(int signo)
{
    g_server_shutdown = 1;
}

void handle_alarm(int signo)
{
    if(g_media_touched > 0) {
	   // printf("media files changed, so update...\n");
    	String media_dir = ConfigManager::getInstance()->getOption("/server/mediadir");
    	String root_obj_id = "1";
    	ContentManager::getInstance()->removeObject(root_obj_id);
    	ContentManager::getInstance()->addFile(media_dir, true);
    	g_media_touched = 0;
    }
    alarm(60);
}

static void handler(int sig, siginfo_t *si, void *data) {}
void * media_monitor(void * params)
{
	int ret = 0;
        struct sigaction act;
        char buffer[BUFFER_SIZE];
        act.sa_sigaction = handler;
        sigemptyset(&act.sa_mask);
        act.sa_flags = SA_SIGINFO;
        sigaction(SIGIO, &act, NULL);

	String media_dir = ConfigManager::getInstance()->getOption("/server/mediadir");
        int fd = open(media_dir.c_str(), O_RDONLY);
        fcntl(fd, F_SETSIG, SIGIO);
        fcntl(fd, F_NOTIFY, DN_CREATE|DN_DELETE|DN_RENAME|DN_RECURSIVE|DN_MULTISHOT|DN_EXTENDED);

        while(!g_server_shutdown)
	{
                *((int*)buffer)=BUFFER_SIZE;
                ret=fcntl(fd,F_NOTIFY+1,buffer);
		// printf("FCNTL return (%d)\n", ret);
                if(ret<0)
                        return 0;
                else if(ret==0)
		{
                        pause();
                }
                else
		{
			g_media_touched += 1;
                }
        }
}

int main(int argc, char **argv, char **envp)
{
    char    c;
    int     opt_index = 0;
    int     o;
    char    *ip = NULL;
    unsigned short  port = 0;
    static struct option long_options[] = {
                   {"ip", 1, 0, 'i'},
                   {"port", 1, 0, 'p'},
                   {"config", 1, 0, 'c'},
                   {"help", 0, 0, 'h'},
                   {0, 0, 0, 0}
               };

    String config_file;
    String home;

    printf("\nMediaTomb UPnP Server version %s\n\n", SERVER_VERSION);
    
    while (1)
    {
        o = getopt_long(argc, argv, OPTSTR, long_options, &opt_index);
        if (o == -1) break;

        switch (o)
        {
            case 'i':
                printf("Option IP with param %s\n", optarg);
                ip = optarg;
                break;

            case 'p':
                printf("Option Port with param %s\n", optarg);
                port = strtol(optarg, (char **)NULL, 10);
                printf("port set to: %d\n", port);
                break;
            case 'c':
                printf("Option config with param %s\n", optarg);

                config_file = optarg;
                    
                break;

            case '?':
                printf("\n");
            case 'h':
                printf("Usage: mediatomb [options]\n\
                        \n\
Supported options:\n\
    --ip or -i         ip address\n\
    --port or -p       server port (the SDK only permits values => 49152)\n\
    --config or -c     configuration file to use\n\
    --help or -h       this help message\n\
\n\
For more information visit http://mediatomb.sourceforge.net/\n\n");

                exit(0);

//            case '?':
//                break;

            default:
                break;
         }
    }

    // TODO: check if -c option is present, if not it is an error NOT to specify config file
    
    try
    {
        char *h = getenv("HOME");
        if (h != NULL) home = h;
/*
        if ((config_file == nil) && (home == nil))
        {
            printf("No configuration specified and no user home directory set.\n");
            exit(1);
        }
*/
        ConfigManager::init(config_file, home);
    }

    catch (mxml::ParseException pe)
    {
        printf("Error parsing config file: %s line %d:\n%s\n",
               pe.context->location.c_str(),
               pe.context->line,
               pe.getMessage().c_str());
        exit(1);
    }
    catch (Exception e)
    {
        printf("%s\n", e.getMessage().c_str());
        exit(1);
    }

    server = Ref<Server>(new Server());
    
    try
    {
        server->init();
        server->upnp_init(ip, port);
    }
    catch(UpnpException upnp_e)
    {
        upnp_e.printStackTrace();
        printf("main: upnp error %d\n ", upnp_e.getErrorCode());
        try
        {
            server->upnp_cleanup();
        }
        catch (Exception e)
        {
            e.printStackTrace();
        }
        exit(1);
    }
    catch (Exception e)
    {
        e.printStackTrace();
        exit(1);
    }

    //init media files
    String media_dir = ConfigManager::getInstance()->getOption("/server/mediadir");
    String root_obj_id = "1";
    ContentManager::getInstance()->removeObject(root_obj_id);
    ContentManager::getInstance()->addFile(media_dir, true);

    // prepare to run processes
    init_process();

    //setup alarm clock    
    struct sigaction nact, oact;
    nact.sa_handler = handle_alarm;
    nact.sa_flags = 0;
    sigaction(SIGALRM, &nact, &oact);
    alarm(60);
    
    //setup sighup handler
    struct sigaction nact2, oact2;
    nact2.sa_handler = handle_sighup;
    nact2.sa_flags = 0;
    sigaction(SIGHUP, &nact2, &oact2);
                   
    //setup media monitor thread
    pthread_attr_t attr;
    pthread_attr_init(&attr);
    pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
    pthread_t monitor_thread;
    pthread_create(&monitor_thread,  &attr, media_monitor, NULL);
    pthread_attr_destroy(&attr);

    //wait for sighup
    while(!g_server_shutdown) pause();
        
    try
    {
        server->upnp_cleanup();
    }
    catch(UpnpException upnp_e)
    {
        printf("main: upnp error %d\n ", upnp_e.getErrorCode());
        exit(1);
    }
    catch (Exception e)
    {
        e.printStackTrace();
        exit(1);
    }
   
    printf("main: end\n");

    return 0;
}
