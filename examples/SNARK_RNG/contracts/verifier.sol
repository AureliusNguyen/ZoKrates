// This file is MIT Licensed.
//
// Copyright 2017 Christian Reitwiessner
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
pragma solidity ^0.8.0;
library Pairing {
    struct G1Point {
        uint X;
        uint Y;
    }
    // Encoding of field elements is: X[0] * z + X[1]
    struct G2Point {
        uint[2] X;
        uint[2] Y;
    }
    /// @return the generator of G1
    function P1() pure internal returns (G1Point memory) {
        return G1Point(1, 2);
    }
    /// @return the generator of G2
    function P2() pure internal returns (G2Point memory) {
        return G2Point(
            [10857046999023057135944570762232829481370756359578518086990519993285655852781,
             11559732032986387107991004021392285783925812861821192530917403151452391805634],
            [8495653923123431417604973247489272438418190587263600148770280649306958101930,
             4082367875863433681332203403145435568316851327593401208105741076214120093531]
        );
    }
    /// @return the negation of p, i.e. p.addition(p.negate()) should be zero.
    function negate(G1Point memory p) pure internal returns (G1Point memory) {
        // The prime q in the base field F_q for G1
        uint q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
        if (p.X == 0 && p.Y == 0)
            return G1Point(0, 0);
        return G1Point(p.X, q - (p.Y % q));
    }
    /// @return r the sum of two points of G1
    function addition(G1Point memory p1, G1Point memory p2) internal view returns (G1Point memory r) {
        uint[4] memory input;
        input[0] = p1.X;
        input[1] = p1.Y;
        input[2] = p2.X;
        input[3] = p2.Y;
        bool success;
        assembly {
            success := staticcall(sub(gas(), 2000), 6, input, 0xc0, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success);
    }


    /// @return r the product of a point on G1 and a scalar, i.e.
    /// p == p.scalar_mul(1) and p.addition(p) == p.scalar_mul(2) for all points p.
    function scalar_mul(G1Point memory p, uint s) internal view returns (G1Point memory r) {
        uint[3] memory input;
        input[0] = p.X;
        input[1] = p.Y;
        input[2] = s;
        bool success;
        assembly {
            success := staticcall(sub(gas(), 2000), 7, input, 0x80, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require (success);
    }
    /// @return the result of computing the pairing check
    /// e(p1[0], p2[0]) *  .... * e(p1[n], p2[n]) == 1
    /// For example pairing([P1(), P1().negate()], [P2(), P2()]) should
    /// return true.
    function pairing(G1Point[] memory p1, G2Point[] memory p2) internal view returns (bool) {
        require(p1.length == p2.length);
        uint elements = p1.length;
        uint inputSize = elements * 6;
        uint[] memory input = new uint[](inputSize);
        for (uint i = 0; i < elements; i++)
        {
            input[i * 6 + 0] = p1[i].X;
            input[i * 6 + 1] = p1[i].Y;
            input[i * 6 + 2] = p2[i].X[1];
            input[i * 6 + 3] = p2[i].X[0];
            input[i * 6 + 4] = p2[i].Y[1];
            input[i * 6 + 5] = p2[i].Y[0];
        }
        uint[1] memory out;
        bool success;
        assembly {
            success := staticcall(sub(gas(), 2000), 8, add(input, 0x20), mul(inputSize, 0x20), out, 0x20)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success);
        return out[0] != 0;
    }
    /// Convenience method for a pairing check for two pairs.
    function pairingProd2(G1Point memory a1, G2Point memory a2, G1Point memory b1, G2Point memory b2) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](2);
        G2Point[] memory p2 = new G2Point[](2);
        p1[0] = a1;
        p1[1] = b1;
        p2[0] = a2;
        p2[1] = b2;
        return pairing(p1, p2);
    }
    /// Convenience method for a pairing check for three pairs.
    function pairingProd3(
            G1Point memory a1, G2Point memory a2,
            G1Point memory b1, G2Point memory b2,
            G1Point memory c1, G2Point memory c2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](3);
        G2Point[] memory p2 = new G2Point[](3);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        return pairing(p1, p2);
    }
    /// Convenience method for a pairing check for four pairs.
    function pairingProd4(
            G1Point memory a1, G2Point memory a2,
            G1Point memory b1, G2Point memory b2,
            G1Point memory c1, G2Point memory c2,
            G1Point memory d1, G2Point memory d2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](4);
        G2Point[] memory p2 = new G2Point[](4);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p1[3] = d1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        p2[3] = d2;
        return pairing(p1, p2);
    }
}

contract Verifier {
    using Pairing for *;
    struct VerifyingKey {
        Pairing.G1Point alpha;
        Pairing.G2Point beta;
        Pairing.G2Point gamma;
        Pairing.G2Point delta;
        Pairing.G1Point[] gamma_abc;
    }
    struct Proof {
        Pairing.G1Point a;
        Pairing.G2Point b;
        Pairing.G1Point c;
    }
    function verifyingKey() pure internal returns (VerifyingKey memory vk) {
        vk.alpha = Pairing.G1Point(uint256(0x301bf0a72cf2057bc9f40aa688beb00bceaf00e78cea825525852b70dfe73015), uint256(0x2c0575306568bc5a980f1bfd600705334d2356bae058d1d899fdc2c5e0d06a44));
        vk.beta = Pairing.G2Point([uint256(0x00b791496d4c732ba59b6c38d09200a13c2e87479023892f0b53ccc3b0c0b89a), uint256(0x10830b05803bae6168f38fce9fecac9ccf77814810c37922ec187618182ff410)], [uint256(0x1897e2a51c475dce998b7d3192c7a7587857473acf020c3779faaf63f5200840), uint256(0x10e075ebb79a346e471e2bfc72b3ee6a2a5ada930db6b0180b43c5f02d7c23fb)]);
        vk.gamma = Pairing.G2Point([uint256(0x30063df56f6b3192b1361c3d19a253a52ee594676cb8b33a16353391f2eaa67f), uint256(0x0a9ecf6aeadb39e0161ed519c420094f0bce76ecf0318642c4ebb962c827da1c)], [uint256(0x066a2632949c37c95fe2b542fe2ecb66118f5fa4949ebe2fb4c0c0861203d326), uint256(0x05a5d6647bdb2702fb497f39517f664ea3518f7ab63f2928f466914a1a8dd333)]);
        vk.delta = Pairing.G2Point([uint256(0x1b32a2f9dfb2485bc9701944a2258e6c746fc625b4fcb97c60cfd71cbadec17d), uint256(0x1154c569b61e70dac6195149975a1885eb8a4259ee159ec55163846fa8e1f2cc)], [uint256(0x00cea9f3ddd8076f620f044c75a49d6b11d716dacf61ec0b8cd738d135249668), uint256(0x03f471f7b51ae1b8d79d4fd3d9b40d02123bb1ac39206181d4d686c99a57fa32)]);
        vk.gamma_abc = new Pairing.G1Point[](11);
        vk.gamma_abc[0] = Pairing.G1Point(uint256(0x233a03fc122529bb80e66c0a12188621177b666296aaa9c1299d81c5f176c60a), uint256(0x02dfc954dffeb0b4f723f35afbadeb35df623597c3a06fe5b59a2a236d423650));
        vk.gamma_abc[1] = Pairing.G1Point(uint256(0x1229cc57a10dff8e14f94855961a468583576acd5edeba313f1e64b88d432725), uint256(0x171f4f3b427654a644011857aadf9c5ec6f9490723bf53867e17ebaa482442af));
        vk.gamma_abc[2] = Pairing.G1Point(uint256(0x05d4561487b784849073fbcf233c0e3807adc59c6d3d6654da8c9bf3410b33df), uint256(0x18a2aebdd0ddd2eee9987b13f98733d865b39f9948babacc017e27b54b69a378));
        vk.gamma_abc[3] = Pairing.G1Point(uint256(0x163c830279c776943cabc1dbf8397a46ece72ccc751e466517206152f62d191b), uint256(0x277c46ec2dcf54a8545ab8f8a53fd7e2a2226dedf78b89e2ab943a4ef981cf9a));
        vk.gamma_abc[4] = Pairing.G1Point(uint256(0x1b40718b423b343a88698ca66489babda4fff3436a3c27996f94cdfe330a7c79), uint256(0x2aca9e91c4842ae9522740a4fecbc5367a558126ba2ca04d1e5045d57c319d07));
        vk.gamma_abc[5] = Pairing.G1Point(uint256(0x201585dfe473fc01dbcdaca5ebe6033794e277e3a42171ae6ba136872cb76120), uint256(0x0930f51e9ab698e2eb373652457b487552b1a7005e5b4c6d13f9eb20f876660c));
        vk.gamma_abc[6] = Pairing.G1Point(uint256(0x0ace9eb7ff9479d1db73cb52c4f3f5a9a6ac40369934447ba4b7592f9b06d4d6), uint256(0x10164c4230146bc00fb09a64f4809b313ca2b727f0976ddd82745c4ddea23f67));
        vk.gamma_abc[7] = Pairing.G1Point(uint256(0x0ce188f4bb05c7dcfd7bd5e27cb1ae720312415bc110a083435f363464a797df), uint256(0x0a4a2166fc14f55a8b2d60f72393dcf4d76c21d1bf100ea08f6c107d97b4865b));
        vk.gamma_abc[8] = Pairing.G1Point(uint256(0x1b0267694119c38ace57ffa647b0d37757ae07d4e1a6a6de22d5aef978fbe7b5), uint256(0x04b3e0f0244302da2e3068fbd7aed926229b2ffd8e2dcf81193d75123fd9bbf4));
        vk.gamma_abc[9] = Pairing.G1Point(uint256(0x0efabf533fafd3ae51b43528799cdd4f181ecfe4b5da22abef44548d03c1d4f1), uint256(0x013fc18787a96f1970e06024a969aa0d4bd3ed862b5f3eb847a45db3076f3c91));
        vk.gamma_abc[10] = Pairing.G1Point(uint256(0x1155e1e59bb4dcd992352ffa40338de05a30aa23d5a4e4d2f5f2c57c6bc060e8), uint256(0x0dd6fc8c904450e66c3292edf56a69f0077238fb8950b8b83bd74c1c3e95b95d));
    }
    function verify(uint[] memory input, Proof memory proof) internal view returns (uint) {
        uint256 snark_scalar_field = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        VerifyingKey memory vk = verifyingKey();
        require(input.length + 1 == vk.gamma_abc.length);
        // Compute the linear combination vk_x
        Pairing.G1Point memory vk_x = Pairing.G1Point(0, 0);
        for (uint i = 0; i < input.length; i++) {
            require(input[i] < snark_scalar_field);
            vk_x = Pairing.addition(vk_x, Pairing.scalar_mul(vk.gamma_abc[i + 1], input[i]));
        }
        vk_x = Pairing.addition(vk_x, vk.gamma_abc[0]);
        if(!Pairing.pairingProd4(
             proof.a, proof.b,
             Pairing.negate(vk_x), vk.gamma,
             Pairing.negate(proof.c), vk.delta,
             Pairing.negate(vk.alpha), vk.beta)) return 1;
        return 0;
    }
    function verifyTx(
            Proof memory proof, uint[10] memory input
        ) public view returns (bool r) {
        uint[] memory inputValues = new uint[](10);
        
        for(uint i = 0; i < input.length; i++){
            inputValues[i] = input[i];
        }
        if (verify(inputValues, proof) == 0) {
            return true;
        } else {
            return false;
        }
    }
}
