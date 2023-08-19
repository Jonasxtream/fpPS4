unit sched_ule;

{$mode ObjFPC}{$H+}
{$CALLING SysV_ABI_CDecl}

interface

uses
 rtprio,
 kern_thr;

procedure sched_fork_thread(td,childtd:p_kthread);
procedure sched_class(td:p_kthread;_class:Integer);
function  sched_priority(td:p_kthread;prio:Integer):Integer;
procedure sched_prio(td:p_kthread;prio:Integer);
procedure sched_user_prio(td:p_kthread;prio:Integer);
procedure sched_lend_user_prio(td:p_kthread;prio:Integer);
procedure sched_sleep(td:p_kthread;prio:Integer);
procedure sched_wakeup(td:p_kthread);
function  sched_switch(td:p_kthread):Integer;

function  setrunnable(td:p_kthread):Integer;

implementation

uses
 atomic,
 md_sleep,
 md_thread;

procedure sched_fork_thread(td,childtd:p_kthread);
begin
 if (td<>nil) then
 begin
  cpuset_setaffinity(childtd,td^.td_cpuset);
  sched_priority(td,td^.td_base_pri);
 end;
end;

procedure sched_class(td:p_kthread;_class:Integer); inline;
begin
 td^.td_pri_class:=_class;
end;

function sched_priority(td:p_kthread;prio:Integer):Integer; inline;
begin
 Result:=cpu_set_priority(td,prio);
end;

procedure sched_prio(td:p_kthread;prio:Integer);
begin
 td^.td_base_pri:=prio;
 sched_priority(td, prio);
end;

procedure sched_user_prio(td:p_kthread;prio:Integer); inline;
begin
 td^.td_base_user_pri:=prio;
 if (td^.td_lend_user_pri<=prio) then Exit;
 td^.td_user_pri:=prio;
end;

function min(a,b:Integer):Integer; inline;
begin
 if (a<b) then Result:=a else Result:=b;
end;

procedure sched_lend_user_prio(td:p_kthread;prio:Integer);
begin
 td^.td_lend_user_pri:=prio;
 td^.td_user_pri:=min(prio,td^.td_base_user_pri);
 if (td^.td_priority>td^.td_user_pri) then
 begin
  sched_prio(td,td^.td_user_pri);
 end;
end;

procedure sched_sleep(td:p_kthread;prio:Integer);
const
 PSOCK=87;
begin
 if TD_IS_SUSPENDED(td) or (prio>=PSOCK) then
 begin
  td^.td_flags:=td^.td_flags or TDF_CANSWAP;
 end;
 if (prio<>0) and (PRI_BASE(td^.td_pri_class)=PRI_TIMESHARE) then
 begin
  sched_prio(td,prio);
 end;
end;

procedure sched_wakeup(td:p_kthread);
begin
 td^.td_flags:=td^.td_flags and (not TDF_CANSWAP);
 TD_SET_RUNNING(td);

 if (td=curkthread) then Exit;
 wakeup_td(td)
end;

function sched_switch(td:p_kthread):Integer;
var
 slptick:Int64;
begin
 atomic_clear_int(@td^.td_flags,TDF_NEEDRESCHED or TDF_SLICEEND);

 slptick:=System.InterlockedExchange64(td^.td_slptick,0);
 Result:=msleep_td(slptick);
end;

function setrunnable(td:p_kthread):Integer;
begin
 Case td^.td_state of
  TDS_RUNNING,
  TDS_RUNQ   :Exit(0);
  TDS_INHIBITED:
    begin
     if (td^.td_inhibitors<>TDI_SWAPPED) then Exit(0);
    end;
  TDS_CAN_RUN:;
  else
     Assert(false,'setrunnable(2)');
 end;

 if ((td^.td_flags and TDF_INMEM)=0) then
 begin
  if ((td^.td_flags and TDF_SWAPINREQ)=0) then
  begin
   td^.td_flags:=td^.td_flags or TDF_SWAPINREQ;
   Exit(1);
  end;
 end else
 begin
  sched_wakeup(td);
 end;
 Exit(0);
end;

end.

