////////////////////////////////////////////////////////////////
// Functions to support instruction fetch/decode
//
// The following functions are not defined in the current
// XML release but are necessary to build a working simulator
////////////////////////////////////////////////////////////////

EndOfInstruction()
    __ExceptionTaken();


boolean __Sleeping;

EnterLowPowerState()
    __Sleeping = TRUE;

ExitLowPowerState()
    __Sleeping = FALSE;

__ResetExecuteState()
    __Sleeping    = FALSE;

ExecuteA64(bits(32) instr)
    __decode A64 instr;

ExecuteT32(bits(16) hw1, bits(16) hw2)
    __decode T32 (hw1 : hw2);

// Implementation of BranchTo and BranchToAddr modified so that we can
// tell that a branch was taken - this is essential for implementing
// PC advance correctly.

boolean __BranchTaken;

BranchTo(bits(N) target, BranchType branch_type)
    __BranchTaken = TRUE; // extra line added
    Hint_Branch(branch_type);
    if N == 32 then
        assert UsingAArch32();
        _PC = ZeroExtend(target);
    else
        assert N == 64 && !UsingAArch32();
        _PC = AArch64.BranchAddr(target[63:0]);
    return;

BranchToAddr(bits(N) target, BranchType branch_type)
    __BranchTaken = TRUE; // extra line added
    Hint_Branch(branch_type);
    if N == 32 then
        assert UsingAArch32();
        _PC = ZeroExtend(target);
    else
        assert N == 64 && !UsingAArch32();
        _PC = target[63:0];
    return;

bits(32) __ThisInstr;

__SetThisInstrDetails(bits(32) opcode)
    __ThisInstr = opcode;
    return;

bits(32) ThisInstr()
    return __ThisInstr;

// Length in bits of instruction
integer ThisInstrLength()
    return 32;

bits(4) AArch32.CurrentCond()
    return __DefaultCond();

bits(N) ThisInstrAddr()
    return _PC[0 +: N];

bits(N) NextInstrAddr()
    return (_PC + (ThisInstrLength() DIV 8))[N-1:0];

bits(32) __FetchInstr(bits(64) pc)
    bits(32) instr;

    CheckSoftwareStep();

    AArch64.CheckPCAlignment();
    AddressDescriptor desc;
    AccessDescriptor accdesc;
    desc.paddress.address = pc[0 +: 52];
    instr = _Mem[desc, 4, accdesc];
    AArch64.CheckIllegalState();

    return instr;

__DecodeExecute(bits(32) instr)
    ExecuteA64(instr);
    return;

// Default condition for an A64 instruction.
// This may be overridden for instructions with explicit condition field.
bits(4) __DefaultCond()
    return 0xE[3:0];

__InstructionExecute()
    try
        __BranchTaken = FALSE;
        bits(64) pc   = ThisInstrAddr();
        instr  = __FetchInstr(pc);
        __SetThisInstrDetails(instr);
        __DecodeExecute(instr);

    catch exn
        // Do not catch UNPREDICTABLE or internal errors
        when IsSEE(exn) || IsUNDEFINED(exn)
            AArch64.UndefinedFault();

        when IsExceptionTaken(exn)
            // Do nothing
            assert TRUE; // This is a bodge around lack of support for empty statements

    if !__BranchTaken then
        _PC = (_PC + (ThisInstrLength() DIV 8))[63:0];

    return;

////////////////////////////////////////////////////////////////
// The following functions define the IMPLEMENTATION_DEFINED behaviour
// of this execution
////////////////////////////////////////////////////////////////

boolean __IMPDEF_boolean(string x)
    if x == "Condition valid for trapped T32" then return TRUE;
    elsif x == "Has Dot Product extension" then return TRUE;
    elsif x == "Has RAS extension" then return TRUE;
    elsif x == "Has SHA512 and SHA3 Crypto instructions" then return TRUE;
    elsif x == "Has SM3 and SM4 Crypto instructions" then return TRUE;
    elsif x == "Has basic Crypto instructions" then return TRUE;
    elsif x == "Have CRC extension" then return TRUE;
    elsif x == "Report I-cache maintenance fault in IFSR" then return TRUE;
    elsif x == "Reserved Control Space EL0 Trapped" then return TRUE;
    elsif x == "Translation fault on misprogrammed contiguous bit" then return TRUE;
    elsif x == "UNDEF unallocated CP15 access at NS EL0" then return TRUE;
    elsif x == "UNDEF unallocated CP15 access at NS EL0" then return TRUE;

    return FALSE;

integer __IMPDEF_integer(string x)
    if x == "Maximum Physical Address Size" then return 52;
    elsif x == "Maximum Virtual Address Size" then return 56;

    return 0;

bits(N) __IMPDEF_bits(integer N, string x)
    if x == "0 or 1" then return Zeros(N);
    elsif x == "FPEXC.EN value when TGE==1 and RW==0" then return Zeros(N);
    elsif x == "reset vector address" then return Zeros(N);

    return Zeros(N);

MemoryAttributes __IMPDEF_MemoryAttributes(string x)
    return MemoryAttributes UNKNOWN;

// todo: implement defaults for these behaviours
// IMPLEMENTATION_DEFINED "floating-point trap handling";
// IMPLEMENTATION_DEFINED "signal slave-generated error";

////////////////////////////////////////////////////////////////
// The following functions are required by my simulator:
// - __TopLevel(): take one atomic step
// - __setPC(): set PC to particular value (used after loading an ELF file)
// - __getPC(): read current value of PC (used to support breakpointing)
// - __conditionPassed: set if executing a conditional instruction
// - __CycleEnd(): deprecated hook called after every instruction execution
// - __ModeString(): generate summary of current mode (used to support tracing)
////////////////////////////////////////////////////////////////

__TakeColdReset()
    PSTATE.nRW = '0'; // boot into A64 mode
    PSTATE.SS = '0';
    __ResetInterruptState();
    __ResetMemoryState();
    __ResetExecuteState();
    AArch64.TakeReset(TRUE);

__TopLevel()
    __InstructionExecute();

__setPC(integer x)
    _PC = x[63:0];
    return;

integer __getPC()
    return UInt(_PC);

boolean __conditionPassed;

__CycleEnd()
    return;

// Function used to generate summary of current state of processor
// (used when generating debug traces)
string __ModeString()
    return "";

////////////////////////////////////////////////////////////////
// End
////////////////////////////////////////////////////////////////
