# Monad Circles

> This project runs on Monad testnet only. The dollar amounts in the app are a test token (mUSDC) that anyone can mint for free. Nothing here has real value, and nobody should send real funds to these contracts.

Monad Circles is a savings circle on Monad, built for the Consumer Products & Payments track of the Metropolis Hackathon.

A savings circle is a group of people who each put in a fixed amount every round. In every round one member takes the whole pot, until everyone has had a turn. It goes by many names (ajo, esusu, tanda, chit fund, susu) and a lot of people already use it. The usual weak point is trust: someone has to hold the cash, and someone has to keep the order fair. Here a contract does both jobs.

- Live app: https://circles.greenerpasturestech.xyz
- Demo video: https://youtu.be/_7q8KkAK-Ek?si=0Q_Elus3bqWMkg3M
- Network: Monad Testnet (chain ID 10143)

## What it does

1. Someone creates a circle by choosing the amount each person pays, how many members, and how long a round lasts. They get an invite link to send to their group.
2. Members open the link and join. Each can save a display name on-chain, so the group can tell who is who.
3. A group chat is available to members from the moment they join.
4. Once the circle is full, the members vote on how pots are paid:
   - **Locked until the end:** every pot stays in the contract until all rounds are done.
   - **Withdraw as you receive:** a member can withdraw a pot after receiving it. If they have not paid the current round yet, that payment is taken from the pot first.
   - A tie means locked, the safer choice. Payments start when everyone has voted, or after one day if someone never votes.
5. Each round, everyone pays. When the last payment lands, the contract picks a random member who has not received a pot yet and credits them. Everybody can see who received which round.
6. In locked mode, credited pots show as locked in each member's view and can be withdrawn after the final round. If a locked circle stalls for two round-lengths, any member can stop it and every member reclaims what they paid in.

The app shows each circle as a 3D scene: a gold pot in the middle, one sphere per member with their name, a green ring on members who have paid this round, and a gold ring on members who already received a pot.

## Why Monad

Savings circles are many small payments from many people, and the rounds finish only when the last person pays. Block times of about a second and very low fees mean the full cycle (pay, draw, credit) completes while everyone is still looking at the screen, and a payment, a vote or a chat message costs a fraction of a cent. On a slower or more expensive chain, chat and voting on-chain would not be practical.

## Deployed contracts (Monad Testnet)

| Contract | Address |
| --- | --- |
| MockUSDC (test token, open mint) | `0x4Df8678F2b555a1bE6C0264C2A8Ab3df20c581c6` |
| CircleFactory | `0xc207fEdF3D33a91fA15528749df8Bc4cf44e35eb` |
| Profiles (display names) | `0xab97F0d0af3f386b56DcBa66aE33989feEaDd3Ff` |

Deployment transactions:

- MockUSDC: `0x3313911dd93ecabea755cc4324d286ecd7da30ef5d1b42fc085d65b44b00eb6f`
- Profiles: `0x2c67fdb370d937b19147ef9a51565503ff5fb378ffa37f95b59bec87443bb55c`
- CircleFactory: `0x7a07eb3f5f8ef094c93409cf28006903bdbc1124c54b4769a9af3444238b4304`

Each circle is its own contract created by the factory. Money, members, votes, chat and draw history for one circle live only in that circle's contract, so groups cannot affect each other.

Explorer: https://testnet.monadvision.com

## Architecture

- `src/Circle.sol`: one savings circle. It moves through the phases Joining, Voting, Active, Finished (or Aborted). It holds the member list, chat messages, votes, payments, the random draw and the withdrawals.
- `src/CircleFactory.sol`: creates circles and keeps a list of them.
- `src/MockUSDC.sol`: a 6-decimal test token with a public `mint`, so anyone can try the app.
- `src/Profiles.sol`: maps a wallet address to a display name of up to 24 characters.
- `frontend/index.html`: the whole app in one file. It uses ethers.js for wallet and contract calls and three.js for the 3D view. A browser wallet (MetaMask, OKX Wallet or another EVM wallet) is required.

The app keeps each person's list of circles in their browser. Opening an invite link adds that circle to the list.

## Tech stack

- Solidity 0.8.x with Foundry (forge) for build and tests
- ethers.js 5.7.2 and three.js r128, loaded from cdnjs
- Plain HTML, CSS and JavaScript, no build step
- Monad Testnet (EVM compatible)

## Run it yourself

Requirements: Foundry, and a browser wallet with testnet MON for gas (faucet: https://faucet.monad.xyz).

Run the contract tests:

```bash
git clone https://github.com/muizcal/monad-circles.git
cd monad-circles
forge test -vv
```

Run the app locally:

```bash
cd frontend
python3 -m http.server 8000
```

Open http://localhost:8000, connect your wallet (the app adds Monad Testnet if needed), click "Get 100 test dollars", and create a circle. To try the full flow you need at least two wallets, each with some testnet MON.

Deploy your own copy of the contracts:

```bash
forge create src/MockUSDC.sol:MockUSDC --rpc-url https://testnet-rpc.monad.xyz --account YOUR_KEYSTORE --broadcast
forge create src/CircleFactory.sol:CircleFactory --rpc-url https://testnet-rpc.monad.xyz --account YOUR_KEYSTORE --broadcast
forge create src/Profiles.sol:Profiles --rpc-url https://testnet-rpc.monad.xyz --account YOUR_KEYSTORE --broadcast
```

Then put the three addresses in the `CFG` block at the top of the script in `frontend/index.html`.

## Known limitations

This is a hackathon prototype. These are the main gaps we know about:

- **The draw is pseudo-random.** It is derived from block data. A determined last payer could influence it slightly. A production version should use a verifiable randomness service.
- **"Withdraw as you receive" still carries trust risk.** The contract takes a member's share for the round they withdraw in, but a member who has withdrawn an early pot could stop paying in later rounds. The poll warns about this and locked mode avoids it. The stop-and-refund exit exists only in locked mode.
- **In locked mode the draw order does not change what anyone ends up with.** Everyone gets back what they paid in. The value there is forced saving, not early access to cash.
- **Anyone with an invite link can join until the circle is full.** There is no allowlist yet.
- **Chat is on-chain and public.** Every message is a transaction, so nothing private should be posted.
- **The public testnet RPC is rate-limited.** If the app says the network is busy, wait a few seconds and try again.
- **Wallets may show a warning for the demo domain.** The app is hosted on a shared vercel.app address, which some wallet security tools flag for any new app. All contracts and transactions are public on the testnet explorer.
- **The token is a test token.** A real deployment would use a real stablecoin, and would need a compliance review in each place it is offered.
- **Login is a normal browser wallet.** Email or passkey login with sponsored gas would suit non-crypto users better and is the next thing we would add.
- **Circle lists are stored per browser.** Opening the invite link again restores a circle on a new device.

## Use of AI tools

I used an AI coding assistant (Claude) to help write and debug the smart contracts, tests and frontend, and to help draft this README. The product design, testing and deployment were done by me.

## Originality

All code in this repository was written during the hackathon period. The only external code is `forge-std` (Foundry's testing library, in `lib/`), plus ethers.js and three.js loaded from a CDN. There was no pre-existing codebase.

## License

MIT. See `LICENSE`.