#ifndef	__MD5_H__
#define	__MD5_H__

#define MD5_MAC_LEN 16
#define SHA_DIGEST_LEN 20

typedef struct _MD5_CTX {
    ULONG   Buf[4];             // buffers of four states
	UCHAR   Input[64];          // input message
	ULONG   LenInBitCount[2];   // length counter for input message, 0 up to 64 bits	                            
}   MD5_CTX;

VOID MD5Init(MD5_CTX *pCtx);
VOID MD5Update(MD5_CTX *pCtx, UCHAR *pData, ULONG LenInBytes);
VOID MD5Final(UCHAR Digest[16], MD5_CTX *pCtx);
VOID MD5Transform(ULONG Buf[4], ULONG Mes[16]);

void md5_mac(UCHAR *key, ULONG key_len, UCHAR *data, ULONG data_len, UCHAR *mac);
void hmac_md5(UCHAR *key, ULONG key_len, UCHAR *data, ULONG data_len, UCHAR *mac);


#endif // __MD5_H__


/******************************************************************************/

VOID SHAInit(SHA_CTX *pCtx);
UCHAR SHAUpdate(SHA_CTX *pCtx, UCHAR *pData, ULONG LenInBytes);
VOID SHAFinal(SHA_CTX *pCtx, UCHAR Digest[20]);
VOID SHATransform(ULONG Buf[5], ULONG Mes[20]);

void hmac_sha1(unsigned char *text, int text_len, unsigned char *key, int key_len, unsigned char *digest);
void F(char *password, unsigned char *ssid, int ssidlength, int iterations, int count, unsigned char *output);
int PasswordHash(char *password, unsigned char *ssid, int ssidlength, unsigned char *output);

/******************************************************************************/
#ifndef	_AES_H
#define	_AES_H

#ifndef	uint8
#define	uint8  unsigned	char
#endif

#ifndef	uint32
#define	uint32 unsigned	long int
#endif

typedef	struct
{
	uint32 erk[64];		/* encryption round	keys */
	uint32 drk[64];		/* decryption round	keys */
	int	nr;				/* number of rounds	*/
}
aes_context;

int	 aes_set_key( aes_context *ctx,	uint8 *key,	int	nbits );
void aes_encrypt( aes_context *ctx,	uint8 input[16], uint8 output[16] );
void aes_decrypt( aes_context *ctx,	uint8 input[16], uint8 output[16] );

#endif /* aes.h	*/

