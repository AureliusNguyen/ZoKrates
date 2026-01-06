# ZoKrates SNARK RNG → Solidity Verifier (Ganache + Truffle) — WSL (Works End‑to‑End)

This README is the _exact_ workflow we ran in WSL to:

1. generate a ZoKrates Groth16 proof (`proof.json`)
2. export a Solidity verifier (`verifier.sol`)
3. deploy the verifier on a local chain (Ganache)
4. verify the proof in Truffle console
5. show that _changing public inputs (“cheat”)_ makes verification fail

It also includes fixes for the two common gotchas we hit:

- Truffle connecting to the wrong port / network id mismatch
- `verifyTx` signature mismatch (2 params vs 4 params)

---

## 1) Install ZoKrates (WSL)

Install ZoKrates into `~/.zokrates`:

```bash
cd ~
curl -LSfs get.zokrat.es | sh
```

Add ZoKrates to PATH (bash):

```bash
echo 'export PATH="$PATH:$HOME/.zokrates/bin"' >> ~/.bashrc
source ~/.bashrc
```

Confirm:

```bash
zokrates --version
```

---

## 2) Install Ganache + Truffle

Install globally:

```bash
npm i -g ganache truffle
ganache --version
truffle version
```

---

## 3) Generate proof + verifier.sol with ZoKrates

Go to your folder:

```bash
cd /SNARK_RNG
```

### 3.1 Compile and setup

```bash
zokrates compile -i root.zok
zokrates setup
```

### 3.2 Compute witness (inputs depend on your program)

Run with your program’s args. Example format:

```bash
zokrates compute-witness --verbose -i reveal_bit -a 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 510
```

Then:

```bash
zokrates generate-proof
zokrates verify
```

You should see `PASSED`.

### 3.3 Export Solidity verifier

```bash
zokrates export-verifier
```

This produces `verifier.sol` in the current folder.

---

## 4) Start a local chain (Ganache)

Pick **one** port and stick to it. We’ll use **7545** here.

In a separate terminal:

```bash
ganache -p 7545
```

Leave Ganache running.

---

## 5) Create a Truffle project + compile verifier.sol

In the same folder (`SNARK_RNG`) initialize Truffle:

```bash
truffle init
```

Copy the ZoKrates verifier into the Truffle `contracts/` directory:

```bash
cp verifier.sol contracts/verifier.sol
```

Check Solidity version required by the verifier:

```bash
grep -n "pragma solidity" contracts/verifier.sol
```

You should get something like:

```
pragma solidity ^0.8.0;
```

### 5.1 Edit truffle-config.js (IMPORTANT)

Open `truffle-config.js` and ensure you have:

- A `development` network pointing to **127.0.0.1:7545**
- `network_id: "*"` (prevents “network id mismatch” errors)
- `compilers.solc.version: "0.8.0"` (must match `verifier.sol` pragma)

Use this as a known-good template:

```js
module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*",
    },
  },
  compilers: {
    solc: {
      version: "0.8.0",
    },
  },
};
```

### 5.2 Compile

```bash
truffle compile
```

You should see something like:

- `Compiled successfully using solc 0.8.0...`

---

## 6) Deploy + verify proof in Truffle console

Start the Truffle console:

```bash
truffle console --network development
```

Inside the `truffle(development)>` prompt:

### 6.1 Deploy verifier

```js
const Verifier = artifacts.require("Verifier");
const contract = await Verifier.new();
contract.address;
```

### 6.2 Load proof.json

Because `proof.json` is in the same folder:

```js
const fs = require("fs");
const proof = JSON.parse(fs.readFileSync("proof.json", "utf8"));
```

### 6.3 Verify proof

In our generated ABI, `verifyTx` expects **2 parameters**:

- `proof` as one tuple containing `(a, b, c)`
- `inputs` as the public input array

So use:

```js
await contract.verifyTx.call(
  [proof.proof.a, proof.proof.b, proof.proof.c],
  proof.inputs
);
```

Expected: `true`

> If you try `verifyTx(a,b,c,inputs)` you’ll get:
> “Invalid number of parameters … expected 2” (because the ABI differs per generator version).

---

## 7) Cheat test (should return false)

Create a modified copy of the inputs (flip the last bit-ish field):

```js
let cheat = [...proof.inputs];
cheat[cheat.length - 1] = cheat[cheat.length - 1].replace(
  /[01]$/,
  cheat[cheat.length - 1][65] === "1" ? "0" : "1"
);
```

Now verify using the same proof but modified inputs:

```js
await contract.verifyTx.call(
  [proof.proof.a, proof.proof.b, proof.proof.c],
  cheat
);
```

Expected: `false`

### Final sanity check (the exact “end state”)

```js
await contract.verifyTx.call(
  [proof.proof.a, proof.proof.b, proof.proof.c],
  proof.inputs
); // true
await contract.verifyTx.call(
  [proof.proof.a, proof.proof.b, proof.proof.c],
  cheat
); // false
```

---

## Common errors & fixes

### 1) “Couldn't connect to node http://127.0.0.1:7545”

- Ganache isn’t running, or wrong port.
  Fix:
- Start Ganache: `ganache -p 7545`
- Or change `port:` in `truffle-config.js` to match your Ganache port.

### 2) “network id specified … does not match …”

Fix:

- Set `network_id: "*"` in `truffle-config.js`.

### 3) “Invalid number of parameters for verifyTx”

Fix:

- Use the ABI shape your contract expects. In our case:
  ```js
  contract.verifyTx.call([a, b, c], inputs);
  ```
- You can inspect the signature from Truffle by printing:
  ```js
  contract.abi;
  ```

---

## Clean up (optional)

To reset Truffle build artifacts:

```bash
rm -rf build
```

To reset ZoKrates artifacts (be careful: deletes proofs/keys):

```bash
rm -f out witness proof.json proving.key verification.key verifier.sol
```
