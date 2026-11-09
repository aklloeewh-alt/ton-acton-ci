import "@stdlib/gas-payments"
import "@acton/emulation/config"
import "@acton/emulation/network"
import "@acton/emulation/testing"
import "@acton/testing/expect"
import "@acton/types/transaction"
import "@contracts/errors"
import "@contracts/fees"
import "@contracts/messages"
import "@tests/deploy-utils"
import "@tests/elector-utils"
import "@tests/matchers"
import "@tests/pool-utils"
import "@tests/test-utils"
import "@wrappers/Pool.gen"

get fun `poc: invariants hold when pending deposit funds an immediate withdrawal`() {
    val (elector, stakes, limits) = setupElector();
    var (pool, _owner, _notOwner, validator) = setupDeployedPool();
    val nmA = testing.treasury("PocA");
    val nmB = testing.treasury("PocB");

    assertPoolDepositInstant(pool, nmA.address, ton("10000"));

    var elections = announceElections(elector);
    assertPoolNewStake(validator, pool, elector, elections, ton("5000"));

    runElections(elector, stakes, limits);
    pool.sendUpdateVset(validator, DEFAULT_QUERY_ID, { value: ton("1") });

    assertDelayedOperation(pool, nmB.address, false, ton("50000"));
    var p = pool.getPoolData();
    expect(p.pendingDeposits).toEqual(ton("50000") - DEPOSIT_GAS);

    val res = pool.sendTextComment(nmA.address, "w".beginParse(), { value: WITHDRAWAL_GAS });
    var inv = pool.getPoolInvariants();
    expect(inv.allMatch).toBeTrue();

    waitTillRecovery(pool, validator, elector.address);
    val recCursor = testing.createTraceIterationCursor(
        validator,
        createMessage<RecoverStakeCompat>({
            bounce: true,
            dest: pool.address,
            body: RecoverStakeCompat { queryId: DEFAULT_QUERY_ID },
            value: ton("1"),
        }),
    );
    recCursor.executeTill<RecoverStakeOk>({ to: pool.address, aborted: false });

    inv = pool.getPoolInvariants();
    expect(inv.allMatch).toBeTrue();
    val shares = pool.getSharesInfo();
    expect(shares.ownerShareValue as int).toBeGreaterOrEqual(0);
}
