#ifdef _WIN32
#include <winsock2.h>
#include <iphlpapi.h>
#include <stdio.h>
#include <ws2tcpip.h>
#else
#include <sys/socket.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <ifaddrs.h>
#endif

#include <string.h>

void send_discover(int rx_discover_socket)
{
	unsigned char data[64];
        int i;
	int port = 1024;
	static struct sockaddr_in bcast_Addr;
#ifdef _WIN32
        MIB_IPADDRTABLE * ipTable = NULL;
        IP_ADAPTER_INFO * pAdapterInfo;
        MIB_IPADDRROW row;
        ULONG bufLen;
        DWORD ipRet, apRet, dw;
        const char * name;
        unsigned long ipAddr, netmask, baddr;
        unsigned int j;

//AllocConsole();
//freopen("CONIN$", "r", stdin);
//freopen("CONOUT$", "w", stdout);
//freopen("CONOUT$", "w", stderr);
//
//printf("Start discover\n");
	data[0] = 0xEF;
	data[1] = 0xFE;
	data[2] = 0x02;
	for (i = 3; i < 64; i++)
		data[i] = 0;
	memset(&bcast_Addr, 0, sizeof(bcast_Addr)); 
	bcast_Addr.sin_family = AF_INET;
	bcast_Addr.sin_port = htons(port);

	bufLen = 0;
	for (i=0; i<5; i++) {
		ipRet = GetIpAddrTable(ipTable, &bufLen, 0);
		if (ipRet == ERROR_INSUFFICIENT_BUFFER) {
			free(ipTable);  // in case we had previously allocated it
			ipTable = (MIB_IPADDRTABLE *) malloc(bufLen);
		}
		else if (ipRet == NO_ERROR)
			break;
		else {
			free(ipTable);
			ipTable = NULL;
			break;
		}
	}

	if (ipTable) {
		pAdapterInfo = NULL;
		bufLen = 0;
		for (i=0; i<5; i++) {
			apRet = GetAdaptersInfo(pAdapterInfo, &bufLen);
			if (apRet == ERROR_BUFFER_OVERFLOW) {
				free(pAdapterInfo);  // in case we had previously allocated it
				pAdapterInfo = (IP_ADAPTER_INFO *) malloc(bufLen);
			}
			else if (apRet == ERROR_SUCCESS)
				break;
			else {
				free(pAdapterInfo);
				pAdapterInfo = NULL;
				break;
			}
		}

		for (j=0; j<ipTable->dwNumEntries; j++) {
			row = ipTable->table[j];
			// Now lookup the appropriate adaptor-name in the pAdaptorInfos, if we can find it
			name = NULL;
			if (pAdapterInfo) {
				IP_ADAPTER_INFO * next = pAdapterInfo;
				while((next)&&(name==NULL)) {
					IP_ADDR_STRING * ipAddr = &next->IpAddressList;
					while(ipAddr) {
                                                InetPton(AF_INET, ipAddr->IpAddress.String, &dw);
						if (dw == row.dwAddr) {
							name = next->AdapterName;
							break;
						}
						ipAddr = ipAddr->Next;
					}
					next = next->Next;
				}
			}
			ipAddr  = ntohl(row.dwAddr);
			netmask = ntohl(row.dwMask);
			baddr = ipAddr & netmask;
			if (row.dwBCastAddr)
				baddr |= ~netmask;
		        bcast_Addr.sin_addr.S_un.S_addr = htonl(baddr);
			sendto(rx_discover_socket, (char *)data, 63, 0, (const struct sockaddr *)&bcast_Addr, sizeof(bcast_Addr));
		}
		free(pAdapterInfo);
		free(ipTable);
	}
#else
	struct ifaddrs * ifap, * p;

	data[0] = 0xEF;
	data[1] = 0xFE;
	data[2] = 0x02;
	for (i = 3; i < 64; i++)
		data[i] = 0;
	memset(&bcast_Addr, 0, sizeof(bcast_Addr)); 
	bcast_Addr.sin_family = AF_INET;
	bcast_Addr.sin_port = htons(port);
	if (getifaddrs(&ifap) == 0) {
		p = ifap;
		while(p) {
			if ((p->ifa_addr) && p->ifa_addr->sa_family == AF_INET) {
				bcast_Addr.sin_addr = ((struct sockaddr_in *)(p->ifa_broadaddr))->sin_addr;
				sendto(rx_discover_socket, (char *)data, 63, 0, (const struct sockaddr *)&bcast_Addr, sizeof(bcast_Addr));
			}
			p = p->ifa_next;
		}
		freeifaddrs(ifap);
	}
#endif
}

