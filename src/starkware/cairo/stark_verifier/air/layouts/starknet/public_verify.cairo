from starkware.cairo.common.math import assert_le, assert_nn, assert_nn_le
from starkware.cairo.common.pow import pow
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.stark_verifier.air.layout import AirWithLayout
from starkware.cairo.stark_verifier.air.layouts.starknet.autogenerated import (
    BITWISE__RATIO,
    CPU_COMPONENT_HEIGHT,
    EC_OP_BUILTIN_RATIO,
    ECDSA_BUILTIN_RATIO,
    LAYOUT_CODE,
    PEDERSEN_BUILTIN_RATIO,
    POSEIDON__RATIO,
    RC_BUILTIN_RATIO,
)
from starkware.cairo.stark_verifier.air.public_input import PublicInput, SegmentInfo
from starkware.cairo.stark_verifier.air.public_memory import AddrValue
from starkware.cairo.stark_verifier.core.domains import StarkDomains

const MAX_LOG_N_STEPS = 50;
const MAX_RANGE_CHECK = 2 ** 16 - 1;

namespace segments {
    const PROGRAM = 0;
    const EXECUTION = 1;
    const OUTPUT = 2;
    const PEDERSEN = 3;
    const RANGE_CHECK = 4;
    const ECDSA = 5;
    const BITWISE = 6;
    const EC_OP = 7;
    const POSEIDON = 8;
    const N_SEGMENTS = 9;
}

const INITIAL_PC = 1;
const FINAL_PC = INITIAL_PC + 4;

// Returns a zero-terminated list of builtins supported by this layout.
func get_layout_builtins() -> (n_builtins: felt, builtins: felt*) {
    let (builtins_address) = get_label_location(data);
    let n_builtins = 7;
    assert builtins_address[n_builtins] = 0;
    return (n_builtins=n_builtins, builtins=builtins_address);

    data:
    dw 'output';
    dw 'pedersen';
    dw 'range_check';
    dw 'ecdsa';
    dw 'bitwise';
    dw 'ec_op';
    dw 'poseidon';
    dw 0;
}

// Verifies that the public input represents a valid Cairo statement: there exists a memory
// assignment and a valid corresponding program trace satisfying the public memory requirements.
//
// This function verifies that:
// * The 16-bit range-checks are properly configured (0 <= rc_min <= rc_max < 2^16).
// * The layout is valid.
// * The segments for the builtins do not exceed their maximum length (thus,
//   when these builtins are properly used in the program, they will function correctly).
//
// This function DOES NOT verify anything regarding the public memory. This should be verified
// by the user. In particular, it is not validated that:
// * [initial_fp - 2] = initial_fp, which is required to guarantee the "safe call"
//   feature (that is, all "call" instructions will return, even if the called function is
//   malicious). It guarantees that it's not possible to create a cycle in the call stack.
// * the arguments and return values for main() are properly set (e.g., the segment
//   pointers).
// * the requested program is loaded, starting from initial_pc.
// * final_pc points to the end of the program.
// * program output is valid in any sense.
// * The continuous pages are consistent. See public_memory.cairo.
func public_input_validate{range_check_ptr}(
    air: AirWithLayout*, public_input: PublicInput*, stark_domains: StarkDomains*
) {
    assert_nn_le(public_input.log_n_steps, MAX_LOG_N_STEPS);
    let (n_steps) = pow(2, public_input.log_n_steps);
    assert n_steps * CPU_COMPONENT_HEIGHT = stark_domains.trace_domain_size;

    assert_le(0, public_input.rc_min);
    assert_le(public_input.rc_min, public_input.rc_max);
    assert_le(public_input.rc_max, MAX_RANGE_CHECK);

    assert public_input.layout = LAYOUT_CODE;

    // Segments.
    tempvar n_output_uses = (
        public_input.segments[segments.OUTPUT].stop_ptr -
        public_input.segments[segments.OUTPUT].begin_addr
    );
    assert_nn(n_output_uses);

    assert public_input.n_segments = segments.N_SEGMENTS;

    tempvar n_pedersen_copies = n_steps / PEDERSEN_BUILTIN_RATIO;
    tempvar n_pedersen_uses = (
        public_input.segments[segments.PEDERSEN].stop_ptr -
        public_input.segments[segments.PEDERSEN].begin_addr
    ) / 3;
    // Note that the following call implies that n_steps is divisible by
    // PEDERSEN_BUILTIN_RATIO.
    assert_nn_le(n_pedersen_uses, n_pedersen_copies);

    tempvar n_range_check_copies = n_steps / RC_BUILTIN_RATIO;
    tempvar n_range_check_uses = (
        public_input.segments[segments.RANGE_CHECK].stop_ptr -
        public_input.segments[segments.RANGE_CHECK].begin_addr
    );
    // Note that the following call implies that n_steps is divisible by
    // RC_BUILTIN_RATIO.
    assert_nn_le(n_range_check_uses, n_range_check_copies);

    tempvar n_ecdsa_copies = n_steps / ECDSA_BUILTIN_RATIO;
    tempvar n_ecdsa_uses = (
        public_input.segments[segments.ECDSA].stop_ptr -
        public_input.segments[segments.ECDSA].begin_addr
    ) / 2;
    // Note that the following call implies that n_steps is divisible by
    // ECDSA_BUILTIN_RATIO.
    assert_nn_le(n_ecdsa_uses, n_ecdsa_copies);

    tempvar n_bitwise_copies = n_steps / BITWISE__RATIO;
    tempvar n_bitwise_uses = (
        public_input.segments[segments.BITWISE].stop_ptr -
        public_input.segments[segments.BITWISE].begin_addr
    ) / 5;
    // Note that the following call implies that n_steps is divisible by
    // BITWISE__RATIO.
    assert_nn_le(n_bitwise_uses, n_bitwise_copies);

    tempvar n_ec_op_copies = n_steps / EC_OP_BUILTIN_RATIO;
    tempvar n_ec_op_uses = (
        public_input.segments[segments.EC_OP].stop_ptr -
        public_input.segments[segments.EC_OP].begin_addr
    ) / 7;
    // Note that the following call implies that n_steps is divisible by
    // EC_OP_BUILTIN_RATIO.
    assert_nn_le(n_ec_op_uses, n_ec_op_copies);

    tempvar n_poseidon_copies = n_steps / POSEIDON__RATIO;
    tempvar n_poseidon_uses = (
        public_input.segments[segments.POSEIDON].stop_ptr -
        public_input.segments[segments.POSEIDON].begin_addr
    ) / 6;
    // Note that the following call implies that n_steps is divisible by
    // POSEIDON__RATIO.
    assert_nn_le(n_poseidon_uses, n_poseidon_copies);

    return ();
}
