#
# Persistent LLDB helper for iOS debug JIT.
# Flutter's ephemeral copy is overwritten and (on 3.47) omits `return False`,
# which lets LLDB stop on NOTIFY_DEBUGGER_ABOUT_RX_PAGES and SIGBUS (signal 10).
#

import lldb


def handle_new_rx_page(frame: lldb.SBFrame, bp_loc, extra_args, intern_dict):
    """Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages."""
    base = frame.register["x0"].GetValueAsAddress()
    page_len = frame.register["x1"].GetValueAsUnsigned()

    data = bytearray(page_len)
    data[0:8] = b"IHELPED!"

    error = lldb.SBError()
    frame.GetThread().GetProcess().WriteMemory(base, data, error)
    if not error.Success():
        print(f"Failed to write into {base}[+{page_len}]", error)

    # False = do not stop; required so launch is not killed at this breakpoint.
    return False


def __lldb_init_module(debugger: lldb.SBDebugger, _):
    debugger.SetAsync(False)
    target = debugger.GetDummyTarget()
    bp = target.BreakpointCreateByRegex("^NOTIFY_DEBUGGER_ABOUT_RX_PAGES$")
    bp.SetScriptCallbackFunction("{}.handle_new_rx_page".format(__name__))
    bp.SetAutoContinue(True)
    print("-- LLDB integration loaded --")
