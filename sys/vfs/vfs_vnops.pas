unit vfs_vnops;

{$mode ObjFPC}{$H+}
{$CALLING SysV_ABI_CDecl}

interface

uses
 vmount,
 vnamei,
 vfile,
 vfs_vnode,
 kern_mtx;

function  vn_lock(vp:p_vnode;flags:Integer):Integer;

function  vn_open_cred(ndp:p_nameidata;
                       flagp:PInteger;
                       cmode:Integer;
                       vn_open_flags:DWORD;
                       fp:p_file):Integer;

function  vn_writechk(vp:p_vnode):Integer;
function  vn_start_write(vp:p_vnode;mpp:pp_mount;flags:Integer):Integer;
procedure vn_finished_write(mp:p_mount);

function  vn_close(vp:p_vnode;flags:Integer):Integer;

implementation

uses
 errno,
 vnode_if,
 vfcntl,
 vfs_lookup,
 vfs_subr,
 kern_thr,
 kern_synch;

function vn_lock(vp:p_vnode;flags:Integer):Integer;
begin
 Assert((flags and LK_TYPE_MASK)<>0,'vn_lock called with no locktype.');

 repeat
  Result:=VOP_LOCK(vp,flags,{$INCLUDE %FILE%},{$INCLUDE %LINENUM%});
  flags:=flags and (not LK_INTERLOCK);

  Assert(((flags and LK_RETRY)=0) or (Result=0),'LK_RETRY set with incompatible flags (0x%x) or an Result occured (%d)');

  if (Result=0) and
     ((vp^.v_iflag and VI_DOOMED)<>0) and
     ((flags and LK_RETRY)=0) then
  begin
   VOP_UNLOCK(vp,0);
   Result:=ENOENT;
   break;
  end;
 until ((flags and LK_RETRY)=0) or (Result=0);
end;

{
 * Common code for vnode open operations.
 * Check permissions, and call the VOP_OPEN or VOP_CREATE routine.
 *
 * Note that this does NOT free nameidata for the successful case,
 * due to the NDINIT being done elsewhere.
}

function vn_open_cred(ndp:p_nameidata;
                      flagp:PInteger;
                      cmode:Integer;
                      vn_open_flags:DWORD;
                      fp:p_file):Integer;
label
 restart,
 bad;
var
 vp:p_vnode;
 mp:p_mount;
 vat:t_vattr;
 vap:p_vattr;
 fmode,error:Integer;
 accmode:accmode_t;
 mps:Integer;
 vfslocked:Boolean;
begin
 vap:=@vat;

 mps:=ndp^.ni_cnd.cn_flags and MPSAFE;

restart:
 vfslocked:=False;
 fmode:=flagp^;
 if ((fmode and O_CREAT)<>0) then
 begin
  ndp^.ni_cnd.cn_nameiop:=CREATE;
  ndp^.ni_cnd.cn_flags:=ISOPEN or LOCKPARENT or LOCKLEAF or MPSAFE;
  if ((fmode and O_EXCL)=0) and ((fmode and O_NOFOLLOW)=0) then
   ndp^.ni_cnd.cn_flags:=ndp^.ni_cnd.cn_flags or FOLLOW;
  if ((vn_open_flags and VN_OPEN_NOAUDIT)=0) then
   ndp^.ni_cnd.cn_flags:=ndp^.ni_cnd.cn_flags or AUDITVNODE1;
  //bwillwrite();
  error:=_namei(ndp);
  if (error<>0) then
   Exit(error);
  vfslocked:=NDHASGIANT(ndp);
  if (mps=0) then
   ndp^.ni_cnd.cn_flags:=ndp^.ni_cnd.cn_flags and (not MPSAFE);
  if (ndp^.ni_vp=nil) then
  begin
   vattr_null(vap);
   vap^.va_type:=VREG;
   vap^.va_mode:=cmode;
   if ((fmode and O_EXCL)<>0) then
    vap^.va_vaflags:=vap^.va_vaflags or VA_EXCLUSIVE;
   if (vn_start_write(ndp^.ni_dvp, @mp, V_NOWAIT)<>0) then
   begin
    NDFREE(ndp, NDF_ONLY_PNBUF);
    vput(ndp^.ni_dvp);
    VFS_UNLOCK_GIANT(ord(vfslocked));
    error:=vn_start_write(nil, @mp, V_XSLEEP or PCATCH);
    if (error<>0) then
     Exit(error);
    goto restart;
   end;

   //error:=mac_vnode_check_create(cred, ndp^.ni_dvp, &ndp^.ni_cnd, vap);
   //if (error=0) then

    error:=VOP_CREATE(ndp^.ni_dvp, @ndp^.ni_vp, @ndp^.ni_cnd, vap);
   vput(ndp^.ni_dvp);
   vn_finished_write(mp);
   if (error<>0) then
   begin
    VFS_UNLOCK_GIANT(ord(vfslocked));
    NDFREE(ndp, NDF_ONLY_PNBUF);
    Exit(error);
   end;
   fmode:=fmode and (not O_TRUNC);
   vp:=ndp^.ni_vp;
  end else
  begin
   if (ndp^.ni_dvp=ndp^.ni_vp) then
    vrele(ndp^.ni_dvp)
   else
    vput(ndp^.ni_dvp);
   ndp^.ni_dvp:=nil;
   vp:=ndp^.ni_vp;
   if ((fmode and O_EXCL)<>0) then
   begin
    error:=EEXIST;
    goto bad;
   end;
   fmode:=fmode and (not O_CREAT);
  end;
 end else
 begin
  ndp^.ni_cnd.cn_nameiop:=LOOKUP;

  ndp^.ni_cnd.cn_flags:=ISOPEN or LOCKLEAF or MPSAFE;

  if ((fmode and O_NOFOLLOW)<>0) then
  begin
   ndp^.ni_cnd.cn_flags:=ndp^.ni_cnd.cn_flags or NOFOLLOW;
  end else
  begin
   ndp^.ni_cnd.cn_flags:=ndp^.ni_cnd.cn_flags or FOLLOW;
  end;

  if ((fmode and FWRITE)=0) then
   ndp^.ni_cnd.cn_flags:=ndp^.ni_cnd.cn_flags or LOCKSHARED;
  if ((vn_open_flags and VN_OPEN_NOAUDIT)=0) then
   ndp^.ni_cnd.cn_flags:=ndp^.ni_cnd.cn_flags or AUDITVNODE1;

  error:=_namei(ndp);
  if (error<>0) then
   Exit(error);
  if (mps=0) then
   ndp^.ni_cnd.cn_flags:=ndp^.ni_cnd.cn_flags and (not MPSAFE);
  vfslocked:=NDHASGIANT(ndp);
  vp:=ndp^.ni_vp;
 end;
 if (vp^.v_type=VLNK) then
 begin
  error:=EMLINK;
  goto bad;
 end;
 if (vp^.v_type=VSOCK) then
 begin
  error:=EOPNOTSUPP;
  goto bad;
 end;
 if (vp^.v_type<>VDIR) and ((fmode and O_DIRECTORY)<>0) then
 begin
  error:=ENOTDIR;
  goto bad;
 end;
 accmode:=0;
 if ((fmode and (FWRITE or O_TRUNC))<>0) then
 begin
  if (vp^.v_type=VDIR) then
  begin
   error:=EISDIR;
   goto bad;
  end;
  accmode:=accmode or VWRITE;
 end;
 if ((fmode and FREAD)<>0) then
  accmode:=accmode or VREAD;
 if ((fmode and FEXEC)<>0) then
  accmode:=accmode or VEXEC;
 if ((fmode and O_APPEND)<>0) and ((fmode and FWRITE)<>0) then
  accmode:=accmode or VAPPEND;

 //error:=mac_vnode_check_open(cred, vp, accmode);
 //if (error) then
 // goto bad;

 if ((fmode and O_CREAT)=0) then
 begin
  if ((accmode and VWRITE)<>0) then
  begin
   error:=vn_writechk(vp);
   if (error<>0) then
    goto bad;
  end;
  if (accmode<>0) then
  begin
   error:=VOP_ACCESS(vp, accmode);
   if (error<>0) then
    goto bad;
  end;
 end;
 if (vp^.v_type=VFIFO) and (VOP_ISLOCKED(vp)<>LK_EXCLUSIVE) then
  vn_lock(vp, LK_UPGRADE or LK_RETRY);

 error:=VOP_OPEN(vp, fmode, fp);
 if (error<>0) then
  goto bad;

 if (fmode and FWRITE)<>0 then
  VOP_ADD_WRITECOUNT(vp, 1);
 flagp^:=fmode;
 ASSERT_VOP_LOCKED(vp, 'vn_open_cred');
 if (mps=0) then
  VFS_UNLOCK_GIANT(ord(vfslocked));
 Exit(0);
bad:
 NDFREE(ndp, NDF_ONLY_PNBUF);
 vput(vp);
 VFS_UNLOCK_GIANT(ord(vfslocked));
 flagp^:=fmode;
 ndp^.ni_vp:=nil;
 Exit(error);
end;

function vn_writechk(vp:p_vnode):Integer;
begin
 ASSERT_VOP_LOCKED(vp, 'vn_writechk');

 if (VOP_IS_TEXT(vp)<>0) then
  Exit(ETXTBSY);

 Exit(0);
end;

function vn_start_write_locked(mp:p_mount;flags:Integer):Integer;
label
 unlock;
var
 error:Integer;
begin
 mtx_assert(MNT_MTX(mp)^);
 error:=0;

 {
  * Check on status of suspension.
  }
 if ((curkthread^.td_pflags and TDP_IGNSUSP)=0) or
    (mp^.mnt_susp_owner<>curkthread) then
 begin
  while ((mp^.mnt_kern_flag and MNTK_SUSPEND)<>0) do
  begin
   if ((flags and V_NOWAIT)<>0) then
   begin
    error:=EWOULDBLOCK;
    goto unlock;
   end;
   error:=msleep(@mp^.mnt_flag, MNT_MTX(mp), (PUSER - 1) or (flags and PCATCH), 'suspfs', 0);
   if (error<>0) then
    goto unlock;
  end;
 end;
 if ((flags and V_XSLEEP)<>0) then
  goto unlock;
 Inc(mp^.mnt_writeopcount);
unlock:
 if (error<>0) or ((flags and V_XSLEEP)<>0) then
  MNT_REL(mp);
 MNT_IUNLOCK(mp);
 Exit (error);
end;

function vn_start_write(vp:p_vnode;mpp:pp_mount;flags:Integer):Integer;
var
 mp:p_mount;
 error:Integer;
begin
 error:=0;
 {
  * If a vnode is provided, get and Exit the mount point that
  * to which it will write.
  }
 if (vp<>nil) then
 begin
  error:=VOP_GETWRITEMOUNT(vp, mpp);
  if (error<>0) then
  begin
   mpp^:=nil;
   if (error<>EOPNOTSUPP) then
    Exit(error);
   Exit(0);
  end;
 end;
 mp:=mpp^;
 if (mp=nil) then
  Exit(0);

 {
  * VOP_GETWRITEMOUNT() Exits with the mp refcount held through
  * a vfs_ref().
  * As long as a vnode is not provided we need to acquire a
  * refcount for the provided mountpoint too, in order to
  * emulate a vfs_ref().
  }
 MNT_ILOCK(mp);
 if (vp=nil) then
  MNT_REF(mp);

 Exit(vn_start_write_locked(mp, flags));
end;


procedure vn_finished_write(mp:p_mount);
begin
 if (mp=nil) then
  Exit;
 MNT_ILOCK(mp);
 MNT_REL(mp);
 Dec(mp^.mnt_writeopcount);
 if (mp^.mnt_writeopcount < 0) then
  Assert(false,'vn_finished_write: neg cnt');
 if ((mp^.mnt_kern_flag and MNTK_SUSPEND)<>0) and (mp^.mnt_writeopcount<=0) then
  wakeup(@mp^.mnt_writeopcount);
 MNT_IUNLOCK(mp);
end;

function vn_close(vp:p_vnode;flags:Integer):Integer;
var
 mp:p_mount;
 error, lock_flags:Integer;
begin
 if (vp^.v_type<>VFIFO) and
    ((flags and FWRITE)=0) and
    (vp^.v_mount<>nil) and
    ((p_mount(vp^.v_mount)^.mnt_kern_flag and MNTK_EXTENDED_SHARED)<>0) then
  lock_flags:=LK_SHARED
 else
  lock_flags:=LK_EXCLUSIVE;

 VFS_ASSERT_GIANT(vp^.v_mount);

 vn_start_write(vp, @mp, V_WAIT);
 vn_lock(vp, lock_flags or LK_RETRY);
 if ((flags and FWRITE)<>0) then
 begin
  Assert(vp^.v_writecount > 0,'vn_close: negative writecount');
  VOP_ADD_WRITECOUNT(vp, -1);
 end;
 error:=VOP_CLOSE(vp, flags);
 vput(vp);
 vn_finished_write(mp);
 Exit(error);
end;

end.
