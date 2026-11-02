/*************************************************************************
 * Ralink Tech Inc.                                                      *
 * 4F, No. 2 Technology 5th Rd.                                          *
 * Science-based Industrial Park                                         *
 * Hsin-chu, Taiwan, R.O.C.                                              *
 *                                                                       *
 * (c) Copyright 2002, Ralink Technology, Inc.                           *
 *                                                                       *
 * This program is free software; you can redistribute it and/or modify  * 
 * it under the terms of the GNU General Public License as published by  * 
 * the Free Software Foundation; either version 2 of the License, or     * 
 * (at your option) any later version.                                   * 
 *                                                                       * 
 * This program is distributed in the hope that it will be useful,       * 
 * but WITHOUT ANY WARRANTY; without even the implied warranty of        * 
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         * 
 * GNU General Public License for more details.                          * 
 *                                                                       * 
 * You should have received a copy of the GNU General Public License     * 
 * along with this program; if not, write to the                         * 
 * Free Software Foundation, Inc.,                                       * 
 * 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             * 
 *                                                                       * 
 *************************************************************************

    Module Name:
    rtmp_main.c

    Abstract:

    Revision History:
    Who         When            What
    --------    ----------      ----------------------------------------------
    Name        Date            Modification logs
    Paul Lin    2002-11-25      Initial version
*/

#include "rt_config.h"

#ifdef CONFIG_PADRE
#ifdef CONFIG_KMOD
#include <linux/kmod.h>
#endif // CONFIG_KMOD
#endif // CONFIG_PADRE

#define DEVNAME "wlan%d"

//  Global static variable, Debug level flag
#ifdef RT2500_DBG
ULONG   RTDebugLevel = RT_DEBUG_TRACE;
#endif

// Following information will be show when you run 'modinfo'
// *** If you have a solution for the bug in current version of driver, please mail to me.
// Otherwise post to forum in ralinktech's web site(www.ralinktech.com) and let all users help you. ***
MODULE_AUTHOR("Paul Lin <paul_lin@ralinktech.com>");
MODULE_DESCRIPTION("Ralink RT2500 802.11b/g WLAN driver ");

//#if LINUX_VERSION_CODE >= 0x20412       // Red Hat 7.3
//MODULE_LICENSE("GPL");
//#endif

extern	const struct iw_handler_def rt2500_iw_handler_def;

#ifdef CONFIG_PADRE
#ifdef CONFIG_HOTPLUG
/*
 * Calls /etc/hotplug
 */
static inline void wireless_hotplug(char *verb, char *state, char *wlan)
{
	char *argv [3], **envp, *buf, *scratch;
	int i = 0, value;

	if (!hotplug_path [0])
		return;
	if(!(envp = (char **) kmalloc (20 * sizeof (char *), GFP_KERNEL))) {
		printk (KERN_DEBUG __FILE__ ":enomem");
		return;
	}
	if(!(buf = kmalloc (256, GFP_KERNEL))) {
		kfree (envp);
		printk (KERN_DEBUG __FILE__ ":enomem2");
		return;
	}

	/* only one standardized param to hotplug command: type */
	argv [0] = hotplug_path;
	argv [1] = "wireless";
	argv [2] = 0;

	/* minimal command environment */
	envp [i++] = "HOME=/";
	envp [i++] = "PATH=/sbin:/bin:/usr/sbin:/usr/bin";

#ifdef CONFIG_HOTPLUG_DEBUG
	/* hint that policy agent should enter no-stdout debug mode */
	envp [i++] = "DEBUG=kernel";
#endif // CONFIG_HOTPLUG_DEBUG
	/* extensible set of named bus-specific parameters,
	 * supporting multiple driver selection algorithms.
	 */
	scratch = buf;

	/* action: up, down */
	envp [i++] = scratch;
	scratch += sprintf(scratch, "ACTION=%s", verb) + 1;
	envp [i++] = scratch;
	scratch += sprintf(scratch, "STATE=%s", state) + 1;
	envp [i++] = scratch;
	scratch += sprintf(scratch, "DEVICE=%s", wlan) + 1;
	envp [i++] = scratch;

	envp [i++] = 0;
	/* assert: (scratch - buf) < sizeof buf */

	/* NOTE: user mode daemons can call the agents too */

	value = call_usermodehelper (argv [0], argv, envp);
	kfree (buf);
	kfree (envp);
	if (value != 0)
		printk (KERN_INFO __FILE__ ":hotplug wireless returned 0x%x", value);
}

#endif // CONFIG_HOTPLUG
#endif // CONFIG_PADRE

static INT __devinit RT2500_init_one (
    IN  struct pci_dev              *pPci_Dev,
    IN  const struct pci_device_id  *ent)
{
    INT rc;

    // wake up and enable device
    if (pci_enable_device (pPci_Dev))
    {
        rc = -EIO;
    }
    else
    {
        rc = RT2500_probe(pPci_Dev, ent);
    }
    return rc;
}

#if LINUX_VERSION_CODE <= 0x20402       // Red Hat 7.1
static struct net_device *alloc_netdev(int sizeof_priv, const char *mask, void (*setup)(struct net_device *))
{
    struct net_device *dev;
    int alloc_size;

    /* ensure 32-byte alignment of the private area */
    alloc_size = sizeof (*dev) + sizeof_priv + 31;

    dev = (struct net_device *) kmalloc (alloc_size, GFP_KERNEL);
    if (dev == NULL)
    {
        DBGPRINT(RT_DEBUG_ERROR, "alloc_netdev: Unable to allocate device memory.\n");
        return NULL;
    }

    memset(dev, 0, alloc_size);

    if (sizeof_priv)
        dev->priv = (void *) (((long)(dev + 1) + 31) & ~31);

    setup(dev);
    strcpy(dev->name,mask);

    return dev;
}
#endif

//
// PCI device probe & initialization function
//
INT __devinit   RT2500_probe(
    IN  struct pci_dev              *pPci_Dev, 
    IN  const struct pci_device_id  *ent)
{
    struct  net_device      *net_dev;
    RTMP_ADAPTER            *pAd;
    CHAR                    *print_name;
    INT                     chip_id = (int) ent->driver_data;
    unsigned long           csr_addr;
    CSR3_STRUC              StaMacReg0;
    CSR4_STRUC              StaMacReg1;
    INT                     Status;

    print_name = pPci_Dev ? pPci_Dev->slot_name : "rt2500";

#if LINUX_VERSION_CODE <= 0x20402       // Red Hat 7.1
    net_dev = alloc_netdev(sizeof(RTMP_ADAPTER), "eth%d", ether_setup);
#else
    net_dev = alloc_etherdev(sizeof(RTMP_ADAPTER));
#endif
    if (net_dev == NULL) 
    {
        DBGPRINT(RT_DEBUG_TRACE, "init_ethernet failed\n");
        goto err_out;
    }

    SET_MODULE_OWNER(net_dev);
        
    if (pci_request_regions(pPci_Dev, print_name))
        goto err_out_free_netdev;

    // Interrupt IRQ number
    net_dev->irq = pPci_Dev->irq;

    // map physical address to virtual address for accessing register
    csr_addr = (unsigned long) ioremap(pci_resource_start(pPci_Dev, 0), pci_resource_len(pPci_Dev, 0));
    if (!csr_addr) 
    {
        DBGPRINT(RT_DEBUG_TRACE, "ioremap failed for device %s, region 0x%X @ 0x%lX\n",
            pPci_Dev->slot_name, (ULONG)pci_resource_len(pPci_Dev, 0), pci_resource_start(pPci_Dev, 0));
        goto err_out_free_res;
    }

    // Save CSR virtual address and irq to device structure
    net_dev->base_addr = csr_addr;
    pAd = net_dev->priv;
    pAd->CSRBaseAddress = net_dev->base_addr;
    pAd->net_dev = net_dev;

    // Set DMA master
    pci_set_master(pPci_Dev);

    // Read MAC address
    NICReadAdapterInfo(pAd);
    
    RTMP_IO_READ32(pAd, CSR3, &StaMacReg0.word);
    RTMP_IO_READ32(pAd, CSR4, &StaMacReg1.word);
    net_dev->dev_addr[0] = StaMacReg0.field.Byte0;
    net_dev->dev_addr[1] = StaMacReg0.field.Byte1;
    net_dev->dev_addr[2] = StaMacReg0.field.Byte2;
    net_dev->dev_addr[3] = StaMacReg0.field.Byte3;
    net_dev->dev_addr[4] = StaMacReg1.field.Byte4;
    net_dev->dev_addr[5] = StaMacReg1.field.Byte5;

    pAd->chip_id = chip_id;
    pAd->pPci_Dev = pPci_Dev;

    // The chip-specific entries in the device structure.
    net_dev->open = RT2500_open;
    net_dev->hard_start_xmit = RTMPSendPackets;
    net_dev->stop = RT2500_close;
    net_dev->get_stats = RT2500_get_ether_stats;

#if WIRELESS_EXT >= 12
    net_dev->get_wireless_stats = RT2500_get_wireless_stats;
	net_dev->wireless_handlers = (struct iw_handler_def *) &rt2500_iw_handler_def;
#endif

    net_dev->set_multicast_list = RT2500_set_rx_mode;
    net_dev->do_ioctl = RT2500_ioctl;

    {// find available 
        int     i=0;
        char    slot_name[IFNAMSIZ];
        struct net_device   *device;

        for (i = 0; i < 8; i++)
        {
            //sprintf(slot_name, "ra%d", i);
	    sprintf(slot_name, DEVNAME, i);
            
            for (device = dev_base; device != NULL; device = device->next)
            {
                if (strncmp(device->name, slot_name, 6) == 0)	// it was 4 for raN.
                {
                    break;
                }
            }
            if(device == NULL)  break;
        }
        if(i == 8)
        {
            DBGPRINT(RT_DEBUG_ERROR, "No available slot name\n");
            goto err_out_unmap;
        }

        //sprintf(net_dev->name, "ra%d", i);
	sprintf(net_dev->name, DEVNAME, i);
    }

    // Register this device
    Status = register_netdev(net_dev);
    if (Status)
        goto err_out_unmap;

    DBGPRINT(RT_DEBUG_TRACE, "%s: at 0x%lx, VA 0x%1x, IRQ %d. \n", 
        net_dev->name, pci_resource_start(pPci_Dev, 0), (ULONG)csr_addr, pPci_Dev->irq);

    // Set driver data
    pci_set_drvdata(pPci_Dev, net_dev);

    // Infrant
#ifdef CONFIG_PADRE
    pcibios_write_config_byte(pPci_Dev->bus->number, pPci_Dev->devfn, PCI_CACHE_LINE_SIZE, 0);
    *(volatile ULONG*)0x6000010c = 0x302c;			// 3=NOPF 2=PCION 1=B64 0=M66EN
#ifdef CONFIG_HOTPLUG
    wireless_hotplug("link", "up", net_dev->name);
#endif // CONFIG_HOTPLUG
#endif // CONFIG_PADRE
    return 0;

err_out_unmap:
    iounmap((void *)csr_addr);
    release_mem_region(pci_resource_start(pPci_Dev, 0), pci_resource_len(pPci_Dev, 0));
err_out_free_res:
    pci_release_regions(pPci_Dev);
err_out_free_netdev:
    kfree (net_dev);
err_out:
    return -ENODEV;
}

INT RT2500_open(
    IN  struct net_device *net_dev)
{
    PRTMP_ADAPTER   pAd = net_dev->priv;
    INT             status = NDIS_STATUS_SUCCESS;

#if LINUX_VERSION_CODE >= KERNEL_VERSION(2,5,0)
    if (!try_module_get(THIS_MODULE))
    {
        DBGPRINT(RT_DEBUG_ERROR, "%s: cannot reserve module\n", __FUNCTION__);
        return -1;
    }
#else
    MOD_INC_USE_COUNT;
#endif
    
    // 1. Allocate DMA descriptors & buffers
    status = RTMPAllocDMAMemory(pAd);
    if (status != NDIS_STATUS_SUCCESS)
        goto out_module_put;

    // 2. request interrupt
    // Disable interrupts here which is as soon as possible
    // This statement should never be true. We might consider to remove it later
    if (RTMP_TEST_FLAG(pAd, fRTMP_ADAPTER_INTERRUPT_ACTIVE))
    {
        NICDisableInterrupt(pAd);
    }

    status = request_irq(pAd->pPci_Dev->irq, &RTMPIsr, SA_SHIRQ, net_dev->name, net_dev);
    if (status)
    {
        RTMPFreeDMAMemory(pAd);
        goto out_module_put;
    }
    RTMP_SET_FLAG(pAd, fRTMP_ADAPTER_INTERRUPT_IN_USE);

    // 3. Read MAC address
    //NICReadAdapterInfo(pAd);

    DBGPRINT(RT_DEBUG_TRACE, "%s: RT2500_open() irq %d. MAC = %02x:%02x:%02x:%02x:%02x:%02x \n",
        net_dev->name, pAd->pPci_Dev->irq, pAd->CurrentAddress[0], pAd->CurrentAddress[1], pAd->CurrentAddress[2],
        pAd->CurrentAddress[3], pAd->CurrentAddress[4], pAd->CurrentAddress[5]);

    NICInitTransmit(pAd);

    // manufacture default
    PortCfgInit(pAd);

    // Read RaConfig profile parameters  
    RTMPReadParametersFromFile(pAd);

    // initialize MLME
    status = MlmeInit(pAd);

    // Initialize Mlme Memory Handler
    // Allocate 20 nonpaged memory pool which size are MAX_LEN_OF_MLME_BUFFER for use
    status = MlmeInitMemoryHandler(pAd, 20, MAX_LEN_OF_MLME_BUFFER);

    if(status != NDIS_STATUS_SUCCESS)
    {
        free_irq(net_dev->irq, net_dev);
        RTMPFreeDMAMemory(pAd);
        goto out_module_put;
    }

    // Initialize Asics
    NICInitializeAdapter(pAd);

    NICReadEEPROMParameters(pAd);

    NICInitAsicFromEEPROM(pAd);

    // 2nd stage hardware initialization after all parameters are acquired from
    // Registry or E2PROM
    RTMPSetPhyMode(pAd, PHY_11BG_MIXED);

    // Set the timer to check for link beat.
/*    RTMPInitTimer(pAd, &pAd->timer, RT2500_timer);
    RTMPSetTimer(pAd, &pAd->timer, DEBUG_TASK_DELAY);*/

    // Enable interrupt
    NICEnableInterrupt(pAd);

    // Start net interface tx /rx
    netif_start_queue(net_dev);

    netif_carrier_on(net_dev);
    netif_wake_queue(net_dev);

    return 0;

out_module_put:
#if LINUX_VERSION_CODE >= KERNEL_VERSION(2,5,0)
    module_put(THIS_MODULE);
#else
    MOD_DEC_USE_COUNT;
#endif

    return status;
}

VOID RT2500_timer(
    IN  unsigned long data)
{
    RTMP_ADAPTER *pAd = (RTMP_ADAPTER *)data;

//  NICCheckForHang(pAd);

    RTMPSetTimer(pAd, &pAd->timer, DEBUG_TASK_DELAY);
}

/*
    ========================================================================

    Routine Description:
        hard_start_xmit handler

    Arguments:
        skb             point to sk_buf which upper layer transmit
        net_dev         point to net_dev
    Return Value:
        None

    Note:

    ========================================================================
*/
INT RTMPSendPackets(
    IN  struct sk_buff *skb,
    IN  struct net_device *net_dev)
{
    NDIS_STATUS     Status = NDIS_STATUS_SUCCESS;
    PRTMP_ADAPTER   pAdapter = net_dev->priv;

    DBGPRINT(RT_DEBUG_INFO, "<==== RTMPSendPackets\n");

    // Drop packets if no associations
    if (!INFRA_ON(pAdapter) && !ADHOC_ON(pAdapter))
    {
        // Drop send request since there are no physical connection yet
        // Check the association status for infrastructure mode
        // And Mibss for Ad-hoc mode setup
        RTMPFreeSkbBuffer(skb);
    }
    else
    {
        // This function has to manage NdisSendComplete return call within its routine
        // NdisSendComplete will acknowledge upper layer in two steps.
        // 1. Within Packet Enqueue, set the NDIS_STATUS_PENDING
        // 2. Within TxRingTxDone / PrioRingTxDone call NdisSendComplete with final status          
        // initial skb->data_len=0, we will use this variable to store data size when fragment(in TKIP)
        // and skb->len is actual data len
        skb->data_len = skb->len;
        Status = RTMPSendPacket(pAdapter,skb);

        if (Status != NDIS_STATUS_SUCCESS)
        {
            // Errors before enqueue stage
            RTMPFreeSkbBuffer(skb);
        }
    }

    // Dequeue one frame from SendTxWait queue and process it
    // There are two place calling dequeue for TX ring.
    // 1. Here, right after queueing the frame.
    // 2. At the end of TxRingTxDone service routine.
    if ((!RTMP_TEST_FLAG(pAdapter, fRTMP_ADAPTER_BSS_SCAN_IN_PROGRESS)) && 
        (!RTMP_TEST_FLAG(pAdapter, fRTMP_ADAPTER_RADIO_OFF)) &&
        (!RTMP_TEST_FLAG(pAdapter, fRTMP_ADAPTER_RESET_IN_PROGRESS)))
    {
        //RTMPDeQueuePacket(pAdapter, &pAdapter->TxSwQueue0);
        // Call dequeue without selected queue, let the subroutine select the right priority
        // Tx software queue
        RTMPDeQueuePacket(pAdapter);
    }

    return 0;
}

/*
    ========================================================================

    Routine Description:
        Interrupt handler

    Arguments:
        irq                         interrupt line
        dev_instance                Pointer to net_device
        rgs                         store process's context before entering ISR, 
                                    this parameter is just for debug purpose.

    Return Value:
        VOID

    Note:

    ========================================================================
*/
#if LINUX_VERSION_CODE >= KERNEL_VERSION(2,5,0)
irqreturn_t
#else
VOID
#endif
RTMPIsr(
    IN  INT             irq, 
    IN  VOID            *dev_instance, 
    IN  struct pt_regs  *rgs)
{
    struct net_device   *net_dev = dev_instance;
    PRTMP_ADAPTER       pAdapter = net_dev->priv;
    INTSRC_STRUC        IntSource;

    DBGPRINT(RT_DEBUG_INFO, "====> RTMPHandleInterrupt\n");

    // 1. Disable interrupt
	if (RTMP_TEST_FLAG(pAdapter, fRTMP_ADAPTER_INTERRUPT_IN_USE) && RTMP_TEST_FLAG(pAdapter, fRTMP_ADAPTER_INTERRUPT_ACTIVE))
	{
		NICDisableInterrupt(pAdapter);
	}


    //
    // Get the interrupt sources & saved to local variable
    //
    // RTMP_IO_READ32(pAdapter, CSR7, &IntSource);
    RTMP_IO_READ32(pAdapter, CSR7, &IntSource.word);
    RTMP_IO_WRITE32(pAdapter, CSR7, IntSource.word);

    //
    // Handle interrupt, walk through all bits
    // Should start from highest priority interrupt
    // The priority can be adjust by altering processing if statement
    //
    // If required spinlock, each interrupt service routine has to acquire
    // and release itself.
    //
    if (IntSource.field.TbcnExpire)
    {
        DBGPRINT(RT_DEBUG_INFO, "====> RTMPHandleTbcnInterrupt\n");
        RTMPHandleTbcnInterrupt(pAdapter);
    }

    if (IntSource.field.TwakeExpire)
    {
        DBGPRINT(RT_DEBUG_INFO, "====> RTMPHandleTwakeupInterrupt\n");
        RTMPHandleTwakeupInterrupt(pAdapter);
    }

    if (IntSource.field.TatimwExpire)
    {
        DBGPRINT(RT_DEBUG_INFO, "====> RTMPHandleTatimInterrupt\n");
        // RTMPHandleTatimInterrupt(pAdapter);
    }

    if (IntSource.field.EncryptionDone)
    {
        DBGPRINT(RT_DEBUG_INFO, "====> RTMPHandleEncryptionDoneInterrupt\n");
        RTMPHandleEncryptionDoneInterrupt(pAdapter);
    }

    if (IntSource.field.TxRingTxDone)
    {
        DBGPRINT(RT_DEBUG_INFO, "====> RTMPHandleTxRingTxDoneInterrupt\n");
        RTMPHandleTxRingTxDoneInterrupt(pAdapter);
    }

    if (IntSource.field.AtimRingTxDone)
    {
        DBGPRINT(RT_DEBUG_INFO, "====> RTMPHandleAtimRingTxDoneInterrupt\n");
        RTMPHandleAtimRingTxDoneInterrupt(pAdapter);
    }

    if (IntSource.field.PrioRingTxDone)
    {
        DBGPRINT(RT_DEBUG_INFO, "====> RTMPHandlePrioRingTxDoneInterrupt\n");
        RTMPHandlePrioRingTxDoneInterrupt(pAdapter);
    }

    if (IntSource.field.DecryptionDone)
    {
        DBGPRINT(RT_DEBUG_INFO, "====> RTMPHandleDecryptionDoneInterrupt\n");
        RTMPHandleDecryptionDoneInterrupt(pAdapter);
    }

    if (IntSource.field.RxDone)
    {
        DBGPRINT(RT_DEBUG_INFO, "====> RTMPHandleRxDoneInterrupt\n");
        RTMPHandleRxDoneInterrupt(pAdapter);
        RTMPHandleEncryptionDoneInterrupt(pAdapter);
    }

    // Do nothing if Reset in progress
    if (RTMP_TEST_FLAG(pAdapter, fRTMP_ADAPTER_RESET_IN_PROGRESS))
    {
#if LINUX_VERSION_CODE >= KERNEL_VERSION(2,5,0)
        return  IRQ_HANDLED;
#else
        return;
#endif
    }

    //
    // Re-enable the interrupt (disabled in RTMPIsr)
    //
    NICEnableInterrupt(pAdapter);

    DBGPRINT(RT_DEBUG_INFO, "<==== RTMPHandleInterrupt\n");
#if LINUX_VERSION_CODE >= KERNEL_VERSION(2,5,0)
    return  IRQ_HANDLED;
#endif
}

#if WIRELESS_EXT >= 12
/*
    ========================================================================

    Routine Description:
        get wireless statistics

    Arguments:
        net_dev                     Pointer to net_device

    Return Value:
        struct iw_statistics

    Note:
        This function will be called when query /proc

    ========================================================================
*/
struct iw_statistics *RT2500_get_wireless_stats(
    IN  struct net_device *net_dev)
{
    RTMP_ADAPTER *pAd = net_dev->priv;

    DBGPRINT(RT_DEBUG_TRACE, "RT2500_get_wireless_stats --->\n");

    // TODO: All elements are zero before be implemented

    pAd->iw_stats.status = 0;                       // Status - device dependent for now

    pAd->iw_stats.qual.qual = pAd->Mlme.ChannelQuality;//pAd->Mlme.RoamCqi;            // link quality (%retries, SNR, %missed beacons or better...)
    // Infrant
    //pAd->iw_stats.qual.level = pAd->PortCfg.LastRssi - RSSI_TO_DBM_OFFSET;   // signal level (dBm)
    pAd->iw_stats.qual.level = pAd->PortCfg.LastRssi - pAd->PortCfg.RssiToDbm;
        
    pAd->iw_stats.qual.noise =  (pAd->PortCfg.LastR17Value > BBP_R17_DYNAMIC_UP_BOUND) ? BBP_R17_DYNAMIC_UP_BOUND : ((ULONG) pAd->PortCfg.LastR17Value);;           // noise level (dBm)
    pAd->iw_stats.qual.updated = 3;     // Flags to know if updated

    pAd->iw_stats.discard.nwid = 0;     // Rx : Wrong nwid/essid
    pAd->iw_stats.miss.beacon = 0;      // Missed beacons/superframe

    // pAd->iw_stats.discard.code, discard.fragment, discard.retries, discard.misc has counted in other place

    return &pAd->iw_stats;
}
#endif

/*
    ========================================================================

    Routine Description:
        return ethernet statistics counter

    Arguments:
        net_dev                     Pointer to net_device

    Return Value:
        net_device_stats*

    Note:

    ========================================================================
*/
struct net_device_stats *RT2500_get_ether_stats(
    IN  struct net_device *net_dev)
{
    RTMP_ADAPTER *pAd = net_dev->priv;

    DBGPRINT(RT_DEBUG_INFO, "RT2500_get_ether_stats --->\n");

    pAd->stats.rx_packets = pAd->WlanCounters.ReceivedFragmentCount.vv.LowPart;        // total packets received
    pAd->stats.tx_packets = pAd->WlanCounters.TransmittedFragmentCount.vv.LowPart;     // total packets transmitted

    pAd->stats.rx_bytes= pAd->RalinkCounters.ReceivedByteCount;             // total bytes received
    pAd->stats.tx_bytes = pAd->RalinkCounters.TransmittedByteCount;         // total bytes transmitted

    pAd->stats.rx_errors = pAd->Counters.RxErrors;                          // bad packets received
    pAd->stats.tx_errors = pAd->Counters.TxErrors;                          // packet transmit problems

    pAd->stats.rx_dropped = pAd->Counters.RxNoBuffer;                       // no space in linux buffers
    pAd->stats.tx_dropped = pAd->WlanCounters.FailedCount.vv.LowPart;                  // no space available in linux

    pAd->stats.multicast = pAd->WlanCounters.MulticastReceivedFrameCount.vv.LowPart;   // multicast packets received
    pAd->stats.collisions = pAd->Counters.OneCollision + pAd->Counters.MoreCollisions;  // Collision packets

    pAd->stats.rx_length_errors = 0;
    pAd->stats.rx_over_errors = pAd->Counters.RxNoBuffer;                   // receiver ring buff overflow
    pAd->stats.rx_crc_errors = 0;//pAd->WlanCounters.FCSErrorCount;     // recved pkt with crc error
    pAd->stats.rx_frame_errors = pAd->Counters.RcvAlignmentErrors;          // recv'd frame alignment error
    pAd->stats.rx_fifo_errors = pAd->Counters.RxNoBuffer;                   // recv'r fifo overrun
    pAd->stats.rx_missed_errors = 0;                                            // receiver missed packet

    // detailed tx_errors
    pAd->stats.tx_aborted_errors = 0;
    pAd->stats.tx_carrier_errors = 0;
    pAd->stats.tx_fifo_errors = 0;
    pAd->stats.tx_heartbeat_errors = 0;
    pAd->stats.tx_window_errors = 0;

    // for cslip etc
    pAd->stats.rx_compressed = 0;
    pAd->stats.tx_compressed = 0;

    return &pAd->stats;
}

/*
    ========================================================================

    Routine Description:
        Set to filter multicast list

    Arguments:
        net_dev                     Pointer to net_device

    Return Value:
        VOID

    Note:

    ========================================================================
*/
VOID RT2500_set_rx_mode(
    IN  struct net_device *net_dev)
{
    // RTMP_ADAPTER *pAd = net_dev->priv;
    // TODO: set_multicast_list
}

//
// Close driver function
//
INT RT2500_close(
    IN  struct net_device *net_dev)
{
    RTMP_ADAPTER    *pAd = net_dev->priv;
    // LONG            ioaddr = net_dev->base_addr;

    DBGPRINT(RT_DEBUG_TRACE, "%s: ===> RT2500_close\n", net_dev->name);

#ifdef CONFIG_PADRE
#ifdef CONFIG_HOTPLUG
    wireless_hotplug("link", "down", net_dev->name);
#endif // CONFIG_HOTPLUG
#endif // CONFIG_PADRE

    // Stop Mlme state machine
    RTMPCancelTimer(&pAd->PortCfg.RfTuningTimer);
    MlmeHalt(pAd);

    netif_stop_queue(net_dev);
    netif_carrier_off(net_dev);

    // Shut down monitor timer task
    //RTMPCancelTimer(&pAd->timer);

    if (RTMP_TEST_FLAG(pAd, fRTMP_ADAPTER_INTERRUPT_ACTIVE))
    {
        NICDisableInterrupt(pAd);
    }

    // Disable Rx, register value supposed will remain after reset
    NICIssueReset(pAd);

    // Free IRQ
    if (RTMP_TEST_FLAG(pAd, fRTMP_ADAPTER_INTERRUPT_IN_USE))
    {
        // Deregister interrupt function
        free_irq(net_dev->irq, net_dev);
        RTMP_CLEAR_FLAG(pAd, fRTMP_ADAPTER_INTERRUPT_IN_USE);
    }

    // Free Ring buffers
    RTMPFreeDMAMemory(pAd);

#if LINUX_VERSION_CODE >= KERNEL_VERSION(2,5,0)
    module_put(THIS_MODULE);
#else
    MOD_DEC_USE_COUNT;
#endif
    return 0;
}

//
// Remove driver function
//
static VOID __devexit RT2500_remove_one(
    IN  struct pci_dev  *pPci_Dev)
{
    struct net_device   *net_dev = pci_get_drvdata(pPci_Dev);
    // RTMP_ADAPTER        *pAd = net_dev->priv;

    // Unregister network device
    unregister_netdev(net_dev);

    // Unmap CSR base address
    iounmap((char *)(net_dev->base_addr));

    // release memory region
    release_mem_region(pci_resource_start(pPci_Dev, 0), pci_resource_len(pPci_Dev, 0)); 

    // Free pre-allocated net_device memory
    kfree(net_dev);
}

//
// Ralink PCI device table, include all supported chipsets
//
static struct pci_device_id rt2500_pci_tbl[] __devinitdata =
{
    {0x1814, 0x0201, PCI_ANY_ID, PCI_ANY_ID, 0, 0, RT2560A},
    {0,}                                /* terminate list */
};
MODULE_DEVICE_TABLE(pci, rt2500_pci_tbl);

//
// Our PCI driver structure
//
static struct pci_driver rt2500_driver =
{
    name:       "rt2500",
    id_table:   rt2500_pci_tbl,
    probe:      RT2500_init_one,
#if LINUX_VERSION_CODE >= 0x20412 || BIG_ENDIAN == TRUE || RTMP_EMBEDDED == TRUE
    remove:     __devexit_p(RT2500_remove_one),
#else
    remove:     __devexit(RT2500_remove_one),
#endif
};

// =======================================================================
// LOAD / UNLOAD sections
// =======================================================================
//
// Driver module load function
//
static INT __init rt2500_init_module(VOID)
{
    return pci_module_init(&rt2500_driver);
}

//
// Driver module unload function
//
static VOID __exit rt2500_cleanup_module(VOID)
{
    pci_unregister_driver(&rt2500_driver);
}

module_init(rt2500_init_module);
module_exit(rt2500_cleanup_module);
