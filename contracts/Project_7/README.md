# 7. Stake Together

A contract owns 1,000,000 cloud coins. Anyone who stakes cloud coin into the contract starting on the beginDate and holds it for 7 days will receive a reward proportional their portion of the total stake at the expiration. For example, suppose Alice stakes 5,000 cloud coin, but the total amount staked at expiration is 25,000 cloud coin. Alice will then be entitled to 200,000 of the rewards, because she accounted for 20% of all the users.

Warning: it’s very easy to accidentally compute the rewards in such a way that a malicious actor can abuse the system. Think carefully about the corner cases!

## Solution

The solution implements a robust staking mechanism with the following key features:

- **Qualification Logic**: Users must stake for at least 7 days before the deadline to qualify for rewards. This is tracked by storing the `stakeTime` and ensuring `endDate >= stakeTime + 7 days`.
- **Reward Calculation**: Rewards are distributed proportionally based on the user's qualified stake vs. the total qualified stake.
- **Principal Withdrawal**: Users can withdraw their initial principal separate from or together with their rewards after the staking period ends.
- **Security**: The contract mitigates common vulnerabilities by enforcing strict state checks (e.g., preventing duplicate claims, ensuring the reward pool is funded) and using `Ownable` for administrative controls.
- **Testing**: Includes a comprehensive test suite (`StakingCloudTest.t.sol`) validating staking, unstaking, qualification logic, and reward distribution scenarios.
