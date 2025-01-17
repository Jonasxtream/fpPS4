unit elf64;

{$mode objfpc}{$H+}

interface

uses ctypes;

{
 /--------------------------------------\--\
 |SELF Header Structure(t_self_header)  |  |
 +--------------------------------------+--|-\
 |SELF Segment Structure(t_self_segment)|  |  | <- t_self_header.Num_Segments * SizeOf(t_self_segment)
 +--------------------------------------+--|-/
 |ELF Segment Structure(elf64_hdr)      |  |
 +--------------------------------------+--|-\
 |ELF Program header(elf64_phdr)        |  |  | <- elf64_hdr.e_phnum * SizeOf(elf64_phdr)
 +--------------------------------------+--|-/
 |Align(addr,16)                        |  |
 +--------------------------------------+  |
 |SELF authinfo(t_self_authinfo)        |  | <- t_self_header.Header_Size
 +--------------------------------------+  |
 |Content_ID/Digest_SHA_256             |  |
 +--------------------------------------+-/--\
 |Metadata/Segment Certification        |     | <- t_self_header.Meta_size
 +--------------------------------------+----/
 |ELF segments data                     |
 \--------------------------------------/
}

Const
 ET_NONE           =0;
 ET_REL            =1;
 ET_EXEC           =2;
 ET_DYN            =3;
 ET_CORE           =4;
 ET_SCE_EXEC       =$FE00;
 ET_SCE_REPLAY_EXEC=$FE01;
 ET_SCE_RELEXEC    =$FE04;
 ET_SCE_STUBLIB    =$FE0C;
 ET_SCE_DYNEXEC    =$FE10;
 ET_SCE_DYNAMIC    =$FE18;

 EI_MAG0       = 0;     // e_ident[] indexes
 EI_MAG1       = 1;
 EI_MAG2       = 2;
 EI_MAG3       = 3;
 EI_CLASS      = 4;
 EI_DATA       = 5;
 EI_VERSION    = 6;
 EI_OSABI      = 7;
 EI_ABIVERSION = 8;

 EI_NIDENT=16;

 ELFMAG =$464C457F;
 SELFMAG=4;

 EM_NONE       =0;
 EM_X86_64     =62; // AMD x86-64

 PT_NULL             = 0;
 PT_LOAD             = 1;
 PT_DYNAMIC          = 2;
 PT_INTERP           = 3;
 PT_NOTE             = 4;
 PT_SHLIB            = 5;
 PT_PHDR             = 6;
 PT_TLS              = 7;        // Thread local storage segment
 PT_SCE_RELA         = $60000000;
 PT_SCE_DYNLIBDATA   = $61000000;
 PT_SCE_PROCPARAM    = $61000001;
 PT_SCE_MODULE_PARAM = $61000002;
 PT_SCE_RELRO        = $61000010;
 PT_GNU_EH_FRAME     = $6474e550;
 PT_GNU_STACK        = $6474E551;
 PT_SCE_COMMENT      = $6FFFFF00;
 PT_SCE_VERSION      = $6FFFFF01;
 PT_SCE_SEGSYM       = $700000A8;

 // This is the info that is needed to parse the dynamic section of the file
 DT_NULL                     = 0;
 DT_NEEDED                   = 1;
 DT_PLTRELSZ                 = 2;
 DT_PLTGOT                   = 3;
 DT_HASH                     = 4;
 DT_STRTAB                   = 5;
 DT_SYMTAB                   = 6;
 DT_RELA                     = 7;
 DT_RELASZ                   = 8;
 DT_RELAENT                  = 9;
 DT_STRSZ                    =10;
 DT_SYMENT                   =11;
 DT_INIT                     =12;
 DT_FINI                     =13;
 DT_SONAME                   =14;
 DT_RPATH                    =15;
 DT_SYMBOLIC                 =16;
 DT_REL                      =17;
 DT_RELSZ                    =18;
 DT_RELENT                   =19;
 DT_PLTREL                   =20;
 DT_DEBUG                    =21;
 DT_TEXTREL                  =22;
 DT_JMPREL                   =23;
 DT_BIND_NOW                 =24;
 DT_INIT_ARRAY               =25;
 DT_FINI_ARRAY               =26;
 DT_INIT_ARRAYSZ             =27;
 DT_FINI_ARRAYSZ             =28;
 DT_RUNPATH                  =29;
 DT_FLAGS                    =30;
 DT_ENCODING                 =31;
 DT_PREINIT_ARRAY            =32;
 DT_PREINIT_ARRAYSZ          =33;
 DT_SCE_IDTABENTSZ           =$61000005;
 DT_SCE_FINGERPRINT          =$61000007;
 DT_SCE_ORIGINAL_FILENAME    =$61000009;
 DT_SCE_MODULE_INFO          =$6100000D;
 DT_SCE_NEEDED_MODULE        =$6100000F;
 DT_SCE_MODULE_ATTR          =$61000011;
 DT_SCE_EXPORT_LIB           =$61000013;
 DT_SCE_IMPORT_LIB           =$61000015;
 DT_SCE_EXPORT_LIB_ATTR      =$61000017;
 DT_SCE_IMPORT_LIB_ATTR      =$61000019;
 DT_SCE_STUB_MODULE_NAME     =$6100001D;
 DT_SCE_STUB_MODULE_VERSION  =$6100001F;
 DT_SCE_STUB_LIBRARY_NAME    =$61000021;
 DT_SCE_STUB_LIBRARY_VERSION =$61000023;
 DT_SCE_HASH                 =$61000025;
 DT_SCE_PLTGOT               =$61000027;
 DT_SCE_JMPREL               =$61000029;
 DT_SCE_PLTREL               =$6100002B;
 DT_SCE_PLTRELSZ             =$6100002D;
 DT_SCE_RELA                 =$6100002F;
 DT_SCE_RELASZ               =$61000031;
 DT_SCE_RELAENT              =$61000033;
 DT_SCE_STRTAB               =$61000035;
 DT_SCE_STRSZ                =$61000037;
 DT_SCE_SYMTAB               =$61000039;
 DT_SCE_SYMENT               =$6100003B;
 DT_SCE_HASHSZ               =$6100003D;
 DT_SCE_SYMTABSZ             =$6100003F;
 DT_SCE_HIOS                 =$6FFFF000;
 DT_GNU_HASH                 =$6ffffef5;
 DT_VERSYM                   =$6ffffff0;
 DT_RELACOUNT                =$6ffffff9;
 DT_RELCOUNT                 =$6ffffffa;
 DT_FLAGS_1                  =$6ffffffb;
 DT_VERDEF                   =$6ffffffc;
 DT_VERDEFNUM                =$6ffffffd;

 DF_ORIGIN    =$01;
 DF_SYMBOLIC  =$02;
 DF_TEXTREL   =$04;
 DF_BIND_NOW  =$08;
 DF_STATIC_TLS=$10;

 DF_1_BIND_NOW=$01;
 DF_1_NODELETE=$08;
 DF_1_LOADFLTR=$10;
 DF_1_NOOPEN  =$40;

 SHT_SYMTAB=2;
 SHT_STRTAB=3;

 // Relocation types for AMD x86-64 architecture
 R_X86_64_NONE                = 0; // No reloc
 R_X86_64_64                  = 1; // Direct 64 bit
 R_X86_64_PC32                = 2; // PC relative 32 bit signed
 R_X86_64_GOT32               = 3; // 32 bit GOT entry
 R_X86_64_PLT32               = 4; // 32 bit PLT address
 R_X86_64_COPY                = 5; // Copy symbol at runtime
 R_X86_64_GLOB_DAT            = 6; // Create GOT entry
 R_X86_64_JUMP_SLOT           = 7; // Create PLT entry
 R_X86_64_RELATIVE            = 8; // Adjust by program base
 R_X86_64_GOTPCREL            = 9; // 32 bit signed pc relative offset to GOT
 R_X86_64_32                  =10; // Direct 32 bit zero extended
 R_X86_64_32S                 =11; // Direct 32 bit sign extended
 R_X86_64_16                  =12; // Direct 16 bit zero extended
 R_X86_64_PC16                =13; // 16 bit sign extended pc relative
 R_X86_64_8                   =14; // Direct 8 bit sign extended
 R_X86_64_PC8                 =15; // 8 bit sign extended pc relative
 R_X86_64_DTPMOD64            =16; // ID of module containing symbol
 R_X86_64_DTPOFF64            =17; // Offset in module's TLS block
 R_X86_64_TPOFF64             =18; // Offset in initial TLS block
 R_X86_64_TLSGD               =19; // 32 bit signed PC relative offset to two GOT entries for GD symbol
 R_X86_64_TLSLD               =20; // 32 bit signed PC relative offset to two GOT entries for LD symbol
 R_X86_64_DTPOFF32            =21; // Offset in TLS block
 R_X86_64_GOTTPOFF            =22; // 32 bit signed PC relative offset to GOT entry for IE symbol
 R_X86_64_TPOFF32             =23; // Offset in initial TLS block
 R_X86_64_PC64                =24; // PC relative 64 bit
 R_X86_64_GOTOFF64            =25; // 64 bit offset to GOT
 R_X86_64_GOTPC32             =26; // 32 bit signed pc relative offset to GOT
 R_X86_64_GOT64               =27; // 64-bit GOT entry offset
 R_X86_64_GOTPCREL64          =28; // 64-bit PC relative offset to GOT entry
 R_X86_64_GOTPC64             =29; // 64-bit PC relative offset to GOT
 R_X86_64_GOTPLT64            =30; // like GOT64, says PLT entry needed
 R_X86_64_PLTOFF64            =31; // 64-bit GOT relative offset to PLT entry
 R_X86_64_SIZE32              =32; // Size of symbol plus 32-bit addend
 R_X86_64_SIZE64              =33; // Size of symbol plus 64-bit addend
 R_X86_64_GOTPC32_TLSDESC     =34; // GOT offset for TLS descriptor
 R_X86_64_TLSDESC_CALL        =35; // Marker for call through TLS descriptor
 R_X86_64_TLSDESC             =36; // TLS descriptor
 R_X86_64_IRELATIVE           =37; // Adjust indirectly by program base
 R_X86_64_RELATIVE64          =38; // 64bit adjust by program base
 R_X86_64_ORBIS_GOTPCREL_LOAD =40;

 STB_LOCAL =0;
 STB_GLOBAL=1;
 STB_WEAK  =2;

 STT_NOTYPE        = 0; //module_start/module_stop
 STT_OBJECT        = 1;
 STT_FUN           = 2;
 STT_SECTION       = 3;
 STT_FILE          = 4;
 STT_COMMON        = 5;
 STT_TLS           = 6;
 STT_LOOS          =10;
 STT_SCE           =11; //module_start/module_stop

 //ST_LOCAL_NONE      = 0x00
 //ST_LOCAL_OBJECT    = 0x01
 //ST_LOCAL_FUNCTION  = 0x02
 //ST_LOCAL_SECTION   = 0x03
 //ST_LOCAL_FILE      = 0x04
 //ST_LOCAL_COMMON    = 0x05
 //ST_LOCAL_TLS       = 0x06
 //ST_LOCAL_SCE       = 0x0B
 //ST_GLOBAL_NONE     = 0x10
 //ST_GLOBAL_OBJECT   = 0x11
 //ST_GLOBAL_FUNCTION = 0x12
 //ST_GLOBAL_SECTION  = 0x13
 //ST_GLOBAL_FILE     = 0x14
 //ST_GLOBAL_COMMON   = 0x15
 //ST_GLOBAL_TLS      = 0x16
 //ST_GLOBAL_SCE      = 0x1B
 //ST_WEAK_NONE       = 0x20
 //ST_WEAK_OBJECT     = 0x21
 //ST_WEAK_FUNCTION   = 0x22
 //ST_WEAK_SECTION    = 0x23
 //ST_WEAK_FILE       = 0x24
 //ST_WEAK_COMMON     = 0x25
 //ST_WEAK_TLS        = 0x26
 //ST_WEAK_SCE        = 0x2B

 STV_DEFAULT   =0;
 STV_INTERNAL  =1;
 STV_HIDDEN    =2;
 STV_PROTECTED =3;

 SHN_UNDEF=0;

 PF_X=$1;
 PF_W=$2;
 PF_R=$4;

type
 Elf64_Addr  =cuint64;
 Elf64_Half  =cuint16;
 Elf64_SHalf =cint64 ;
 Elf64_Off   =cuint64;
 Elf64_Sword =cint32 ;
 Elf64_Word  =cuint32;
 Elf64_Xword =cuint64;
 Elf64_Sxword=cint64 ;

 p_elf64_hdr=^elf64_hdr;
 elf64_hdr=packed record
  e_ident:Array[0..EI_NIDENT-1] of Byte; // ELF "magic number"
  e_type     :Elf64_Half;
  e_machine  :Elf64_Half;
  e_version  :Elf64_Word;
  e_entry    :Elf64_Addr; // Entry point virtual address from where the process starts executing.
  e_phoff    :Elf64_Off ; // Program header table file offset
  e_shoff    :Elf64_Off ; // Section header table file offset
  e_flags    :Elf64_Word;
  e_ehsize   :Elf64_Half;
  e_phentsize:Elf64_Half;
  e_phnum    :Elf64_Half;
  e_shentsize:Elf64_Half;
  e_shnum    :Elf64_Half;
  e_shstrndx :Elf64_Half;
 end;

 p_elf64_phdr=^elf64_phdr;
 elf64_phdr=packed record
  p_type  :Elf64_Word ;
  p_flags :Elf64_Word ;
  p_offset:Elf64_Off  ; // Segment file offset
  p_vaddr :Elf64_Addr ; // Segment virtual address
  p_paddr :Elf64_Addr ; // Segment physical address
  p_filesz:Elf64_Xword; // Segment size in file
  p_memsz :Elf64_Xword; // Segment size in memory
  p_align :Elf64_Xword; // Segment alignment, file & memory
 end;

 p_elf64_shdr=^elf64_shdr;
 elf64_shdr=packed record
  sh_name     :Elf64_Word ;   // Section name, index in string tbl
  sh_type     :Elf64_Word ;   // Type of section
  sh_flags    :Elf64_Xword;   // Miscellaneous section attributes
  sh_addr     :Elf64_Addr ;   // Section virtual addr at execution
  sh_offset   :Elf64_Off  ;   // Section file offset
  sh_size     :Elf64_Xword;   // Size of section in bytes
  sh_link     :Elf64_Word ;   // Index of another section
  sh_info     :Elf64_Word ;   // Additional section information
  sh_addralign:Elf64_Xword;   // Section alignment
  sh_entsize  :Elf64_Xword;   // Entry size if section holds table
 end;

 p_elf64_dyn=^elf64_dyn;
 elf64_dyn=packed record
  d_tag:Elf64_Sxword;  // entry tag value
  d_un :packed record
   Case Byte of
    0:(d_val:Elf64_Xword);
    1:(d_ptr:Elf64_Addr);
  end;
 end;

 p_elf64_rela=^elf64_rela;
 elf64_rela=packed record
  r_offset:Elf64_Addr;         // Location at which to apply the action
  r_info  :Elf64_Xword;        // index and type of relocation
  r_addend:Elf64_Sxword;       // Constant addend used to compute value
 end;

 p_elf64_sym=^elf64_sym;
 elf64_sym=packed record
  st_name :Elf64_Word;         // Symbol name, index in string tbl
  st_info :Byte;               // Type and binding attributes
  st_other:Byte;               // No defined meaning, 0
  st_shndx:Elf64_Half;         // Associated section index
  st_value:Elf64_Addr;         // Value of the symbol
  st_size :Elf64_Xword;        // Associated symbol size
 end;

const
 SELF_MAGIC     =$1D3D154F;
 SELF_VERSION   =$0;
 SELF_MODE      =$1;
 SELF_ENDIANNESS=$1;

 SELF_AUTH_INFO_SIZE         =$88;
 SELF_KEY_SIZE               =$10;
 SELF_DIGEST_SIZE            =$20;
 SELF_SEGMENT_BLOCK_ALIGNMENT=$10;

type
 p_self_header=^t_self_header;
 t_self_header=packed record
  Magic       :DWORD;       //Magic              4F 15 3D 1D
  Version     :Byte;        //0
  Mode        :Byte;        //1
  Endian      :Byte;        //1
  Attr        :Byte;        //
  Content_Type:Byte;        //Content Type       1 on Self, 4 on PUP Entry
  Program_Type:Byte;        //Program Type
  Padding     :Word;        //Padding
  Header_Size :Word;        //Header Size
  Meta_size   :Word;        //Signature Size     Metadata Size?
  File_size   :QWORD;       //Size of SELF
  Num_Segments:Word;        //Number of Segments
  Flags       :Word;        //
  reserved    :DWORD;       //
 end;

const
 SELF_PROPS_ORDERED       = $00000001;
 SELF_PROPS_ENCRYPTED     = $00000002;
 SELF_PROPS_SIGNED        = $00000004;
 SELF_PROPS_COMPRESSED    = $00000008;
 SELF_PROPS_WINDOW        = $00000700;
 SELF_PROPS_BLOCKED       = $00000800;
 SELF_PROPS_BLOCK_SIZE    = $0000F000;
 SELF_PROPS_HAS_DIGESTS   = $00010000;
 SELF_PROPS_HAS_EXTENTS   = $00020000;
 SELF_PROPS_SEGMENT_INDEX = $7FF00000;

 SELF_PROPS_WINDOW_OFFSET=8;
 SELF_PROPS_WINDOW_MASK  =7;

 SELF_PROPS_BLOCK_SIZE_OFFSET=12;
 SELF_PROPS_BLOCK_SIZE_MASK  =$F;

 SELF_PROPS_SEGMENT_INDEX_OFFSET=20;
 SELF_PROPS_SEGMENT_INDEX_MASK  =$7FF;

 SELF_PT_FAKE         =$1;
 SELF_PT_NPDRM_EXEC   =$4;
 SELF_PT_NPDRM_DYNLIB =$5;
 SELF_PT_SYSTEM_EXEC  =$8;
 SELF_PT_SYSTEM_DYNLIB=$9;
 SELF_PT_HOST_KERNEL  =$C;
 SELF_PT_SECURE_MODULE=$E;
 SELF_PT_SECURE_KERNEL=$F;

type
 p_self_segment=^t_self_segment;
 t_self_segment=packed record
  flags :QWORD;
  offset:QWORD;
  filesz:QWORD;
  memsz :QWORD;
 end;

 p_self_authinfo=^t_self_authinfo;
 t_self_authinfo=packed record
  AuthorityID    :QWORD;
  Program_Type   :QWORD;
  Program_Version:QWORD;
  System_Version :QWORD;
  //Content_ID    :array[0..31] of Byte; //Optional
  Digest_SHA_256 :array[0..31] of Byte;
 end;

 p_eh_frame_hdr=^eh_frame_hdr;
 eh_frame_hdr=packed record
  version         :Byte;
  eh_frame_ptr_enc:Byte;
  fde_count_enc   :Byte;
  table_enc       :Byte;
  encoded:record end;
  //encoded eh_frame_ptr
  //encoded fde_count
 end;

const
 DW_EH_PE_omit   =$ff; // no data follows

 DW_EH_PE_absptr =$00;
 DW_EH_PE_pcrel	 =$10;
 DW_EH_PE_datarel=$30;

 DW_EH_PE_uleb128=$01;
 DW_EH_PE_udata2 =$02;
 DW_EH_PE_udata4 =$03;
 DW_EH_PE_udata8 =$04;
 DW_EH_PE_sleb128=$09;
 DW_EH_PE_sdata2 =$0A;
 DW_EH_PE_sdata4 =$0B;
 DW_EH_PE_sdata8 =$0C;

type
 TModuleValue=packed record
  case Byte of
   0:(value      :Int64);
   1:(name_offset:DWORD;
      version    :Word;
      id         :Word);
 end;

 TLibraryValue=packed record
  case Byte of
   0:(value      :Int64);
   1:(name_offset:DWORD;
      version    :Word;
      id         :Word);
 end;

 TLibraryAttr=packed record
  case Byte of
   0:(value:Int64);
   1:(attr :WORD;
      align:DWORD;
      id   :Word);
 end;

 PTLS_index=^TLS_index;
 TLS_index=packed record
  ti_moduleid :QWORD;
  ti_tlsoffset:QWORD;
 end;

 PPS4StartupParams=^TPS4StartupParams;
 TPS4StartupParams=packed record
  argc:Integer;
  align:Integer;
  argv:array[0..2] of Pointer;
  //envrion = argv + argc + 1
 end;

type
 t_user_malloc_init       =function():Integer;                              SysV_ABI_CDecl;
 t_user_malloc_finalize   =function():Integer;                              SysV_ABI_CDecl;
 t_user_malloc            =function(size:qword):Pointer;                    SysV_ABI_CDecl;
 t_user_free              =procedure(ptr:Pointer);                          SysV_ABI_CDecl;
 t_user_calloc            =function(nelem,count:qword):Pointer;             SysV_ABI_CDecl;
 t_user_realloc           =function(ptr:Pointer;size:qword):Pointer;        SysV_ABI_CDecl;
 t_user_memalign          =function(align,size:qword):Pointer;              SysV_ABI_CDecl;
 t_user_reallocalign      =function(ptr:Pointer;size,align:qword):Pointer;  SysV_ABI_CDecl;
 t_user_posix_memalign    =function(ptr:PPointer;align,size:qword):Integer; SysV_ABI_CDecl;
 t_user_malloc_stats      =function(mmsize:Pointer):Integer;                SysV_ABI_CDecl;
 t_user_malloc_stats_fast =function(mmsize:Pointer):Integer;                SysV_ABI_CDecl;
 t_user_malloc_usable_size=function(ptr:Pointer):qword;                     SysV_ABI_CDecl;

 PsceLibcMallocReplace=^TsceLibcMallocReplace;
 TsceLibcMallocReplace=packed record
  Size:QWORD;
  Unknown1:QWORD; //00000001
  user_malloc_init       :t_user_malloc_init;
  user_malloc_finalize   :t_user_malloc_finalize;
  user_malloc            :t_user_malloc;
  user_free              :t_user_free;
  user_calloc            :t_user_calloc;
  user_realloc           :t_user_realloc;
  user_memalign          :t_user_memalign;
  user_reallocalign      :t_user_reallocalign;
  user_posix_memalign    :t_user_posix_memalign;
  user_malloc_stats      :t_user_malloc_stats;
  user_malloc_stats_fast :t_user_malloc_stats_fast;
  user_malloc_usable_size:t_user_malloc_usable_size;
 end;

 t_user_new_1         =function(size:qword):Pointer;                    SysV_ABI_CDecl;
 t_user_new_2         =function(size:qword;throw:Pointer):Pointer;      SysV_ABI_CDecl;
 t_user_new_array_1   =function(size:qword):Pointer;                    SysV_ABI_CDecl;
 t_user_new_array_2   =function(size:qword;throw:Pointer):Pointer;      SysV_ABI_CDecl;
 t_user_delete_1      =procedure(ptr:Pointer);                          SysV_ABI_CDecl;
 t_user_delete_2      =procedure(ptr:Pointer;throw:Pointer);            SysV_ABI_CDecl;
 t_user_delete_array_1=procedure(ptr:Pointer);                          SysV_ABI_CDecl;
 t_user_delete_array_2=procedure(ptr:Pointer;throw:Pointer);            SysV_ABI_CDecl;
 t_user_delete_3      =procedure(ptr:Pointer;size:qword);               SysV_ABI_CDecl;
 t_user_delete_4      =procedure(ptr:Pointer;size:qword;throw:Pointer); SysV_ABI_CDecl;
 t_user_delete_array_3=procedure(ptr:Pointer;size:qword);               SysV_ABI_CDecl;
 t_user_delete_array_4=procedure(ptr:Pointer;size:qword;throw:Pointer); SysV_ABI_CDecl;

 PsceLibcNewReplace=^TsceLibcNewReplace;
 TsceLibcNewReplace=packed record
  Size:QWORD;
  Unknown1:QWORD; //00000002
  user_new_1         :t_user_new_1;
  user_new_2         :t_user_new_2;
  user_new_array_1   :t_user_new_array_1;
  user_new_array_2   :t_user_new_array_2;
  user_delete_1      :t_user_delete_1;
  user_delete_2      :t_user_delete_2;
  user_delete_array_1:t_user_delete_array_1;
  user_delete_array_2:t_user_delete_array_2;
  user_delete_3      :t_user_delete_3;
  user_delete_4      :t_user_delete_4;
  user_delete_array_3:t_user_delete_array_3;
  user_delete_array_4:t_user_delete_array_4;
 end;

 t_user_malloc_init_for_tls   =function():Integer;                              SysV_ABI_CDecl;
 t_user_malloc_fini_for_tls   =function():Integer;                              SysV_ABI_CDecl;
 t_user_malloc_for_tls        =function(size:qword):Pointer;                    SysV_ABI_CDecl;
 t_user_posix_memalign_for_tls=function(ptr:PPointer;align,size:qword):Integer; SysV_ABI_CDecl;
 t_user_free_for_tls          =procedure(ptr:Pointer);                          SysV_ABI_CDecl;

 PsceLibcMallocReplaceForTls=^TsceLibcMallocReplaceForTls;
 TsceLibcMallocReplaceForTls=packed record
  Size:QWORD;
  Unknown1:QWORD; //00000001
  user_malloc_init_for_tls   :t_user_malloc_init_for_tls;
  user_malloc_fini_for_tls   :t_user_malloc_fini_for_tls;
  user_malloc_for_tls        :t_user_malloc_for_tls;
  user_posix_memalign_for_tls:t_user_posix_memalign_for_tls;
  user_free_for_tls          :t_user_free_for_tls;
 end;

 PSceLibcParam=^TSceLibcParam;
 TSceLibcParam=packed record
  Size:QWORD;
  entry_count:DWORD;
  SceLibcInternalHeap              :DWORD; //1 //(entry_count > 1)
  sceLibcHeapSize                  :PDWORD;
  sceLibcHeapDelayedAlloc          :PDWORD;
  sceLibcHeapExtendedAlloc         :PDWORD;
  sceLibcHeapInitialSize           :PDWORD;
  _sceLibcMallocReplace            :PsceLibcMallocReplace;
  _sceLibcNewReplace               :PsceLibcNewReplace;
  sceLibcHeapHighAddressAlloc      :PQWORD;    //(entry_count > 2)
  Need_sceLibc                     :PDWORD;
  sceLibcHeapMemoryLock            :PQWORD;    //(entry_count > 4)
  sceKernelInternalMemorySize      :PQWORD;
  _sceLibcMallocReplaceForTls      :PsceLibcMallocReplaceForTls;
  //The maximum amount of the memory areas for the mspace. min:0x1000000
  sceLibcMaxSystemSize             :PQWORD;    //(entry_count > 7)
  sceLibcHeapDebugFlags            :PQWORD;    //(entry_count > 8)
  sceLibcStdThreadStackSize        :PDWORD;
  Unknown3:QWORD;
  sceKernelInternalMemoryDebugFlags:PDWORD;
  sceLibcWorkerThreadNum           :PDWORD;
  sceLibcWorkerThreadPriority      :PDWORD;
  sceLibcThreadUnnamedObjects      :PDWORD;
 end;

 PSceKernelMemParam=^TSceKernelMemParam;
 TSceKernelMemParam=packed record
  Size:QWORD;
  sceKernelExtendedPageTable   :PQWORD;
  sceKernelFlexibleMemorySize  :PQWORD;
  sceKernelExtendedMemory1     :PByte;
  sceKernelExtendedGpuPageTable:PQWORD;
  sceKernelExtendedMemory2     :PByte;
  sceKernelExtendedCpuPageTable:PQWORD;
 end;

 PSceKernelFsParam=^TSceKernelFsParam;
 TSceKernelFsParam=packed record
  Size:QWORD;
  sceKernelFsDupDent    :PDWORD;
  sceWorkspaceUpdateMode:Pointer;
  sceTraceAprNameMode   :Pointer;
 end;

 PSceProcParam=^TSceProcParam;
 TSceProcParam=packed record
  Size                      :QWORD; //0x50
  Magic                     :DWORD; //"ORBI" //0x4942524F
  Entry_count               :DWORD; //>=1
  SDK_version               :QWORD; //0x4508101
  sceProcessName            :PChar;
  sceUserMainThreadName     :PChar;
  sceUserMainThreadPriority :PDWORD;
  sceUserMainThreadStackSize:PDWORD;
  _sceLibcParam             :PSceLibcParam;
  _sceKernelMemParam        :PSceKernelMemParam;
  _sceKernelFsParam         :PSceKernelFsParam;
  sceProcessPreloadEnabled  :PDWORD;
  Unknown1                  :QWORD;
 end;

 PsceModuleParam=^TsceModuleParam;
 TsceModuleParam=packed record
  Size       :QWORD;
  Magic      :QWORD;
  SDK_version:QWORD;
 end;

function SELF_WINDOW(i:Int64):Integer; inline;
function SELF_BLOCK_SIZE(i:Int64):Int64; inline;
function SELF_SEGMENT_INDEX(i:Int64):Integer; inline;

function ELF64_R_SYM (i:QWORD):DWORD; inline;
function ELF64_R_TYPE(i:QWORD):DWORD; inline;
function ELF64_ST_BIND(i:Byte):Byte; inline;
function ELF64_ST_TYPE(i:Byte):Byte; inline;
function ELF64_ST_VISIBILITY(i:Byte):Byte; inline;

function AlignUp(addr:PtrUInt;alignment:PtrUInt):PtrUInt; inline;
function AlignUp(addr:Pointer;alignment:PtrUInt):Pointer; inline;
function AlignDw(addr:PtrUInt;alignment:PtrUInt):PtrUInt; inline;
function AlignDw(addr:Pointer;alignment:PtrUInt):Pointer; inline;
function IsAlign(Addr:Pointer;Alignment:PtrUInt):Boolean; inline;
function IsAlign(Addr:PtrUInt;Alignment:PtrUInt):Boolean; inline;

implementation

function SELF_WINDOW(i:Int64):Integer; inline;
begin
 Result:=(i shr SELF_PROPS_WINDOW_OFFSET) and SELF_PROPS_WINDOW_MASK;
end;

function SELF_BLOCK_SIZE(i:Int64):Int64; inline;
begin
 Result:=(i shr SELF_PROPS_BLOCK_SIZE_OFFSET) and SELF_PROPS_BLOCK_SIZE_MASK;
 Result:=1 shl (Result+12)
end;

function SELF_SEGMENT_INDEX(i:Int64):Integer; inline;
begin
 Result:=(i shr SELF_PROPS_SEGMENT_INDEX_OFFSET) and SELF_PROPS_SEGMENT_INDEX_MASK;
end;

function ELF64_R_SYM(i:QWORD):DWORD; inline;
begin
 Result:=i shr 32;
end;

function ELF64_R_TYPE(i:QWORD):DWORD; inline;
begin
 Result:=i and $ffffffff;
end;

function ELF64_ST_BIND(i:Byte):Byte; inline;
begin
 Result:=i shr 4;
end;

function ELF64_ST_TYPE(i:Byte):Byte; inline;
begin
 Result:=i and $f;
end;

function ELF64_ST_VISIBILITY(i:Byte):Byte; inline;
begin
 Result:=i and 3;
end;

function AlignUp(addr:PtrUInt;alignment:PtrUInt):PtrUInt; inline;
var
 tmp:PtrUInt;
begin
 if (alignment=0) then Exit(addr);
 tmp:=addr+PtrUInt(alignment-1);
 Result:=tmp-(tmp mod alignment)
end;

function AlignUp(addr:Pointer;alignment:PtrUInt):Pointer; inline;
begin
 Result:=Pointer(Align(PtrUInt(addr),alignment));
end;

function AlignDw(addr:PtrUInt;alignment:PtrUInt):PtrUInt; inline;
begin
 Result:=addr-(addr mod alignment);
end;

function AlignDw(addr:Pointer;alignment:PtrUInt):Pointer; inline;
begin
 Result:=Pointer(AlignDw(PtrUInt(addr),alignment));
end;

function IsAlign(Addr:Pointer;Alignment:PtrUInt):Boolean; inline;
begin
 Result:=(PtrUInt(addr) mod alignment)=0;
end;

function IsAlign(Addr:PtrUInt;Alignment:PtrUInt):Boolean; inline;
begin
 Result:=(addr mod alignment)=0;
end;

end.

