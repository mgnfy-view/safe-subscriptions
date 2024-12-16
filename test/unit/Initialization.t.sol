// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Safe } from "@safe/Safe.sol";

import { GlobalHelper } from "../utils/GlobalHelper.sol";

contract InitializationTest is GlobalHelper {
    function test_contractsDeployed() public view {
        assertNotEq(address(safeSubscriptions), address(0));
        assertNotEq(singleton, address(0));
        assertNotEq(address(safeProxyFactory), address(0));
        assertNotEq(address(safe), address(0));
    }

    function test_ownersAndThresholdSet() public view {
        assertTrue(safe.isOwner(owners[0]));
        assertTrue(safe.isOwner(owners[1]));
        assertTrue(safe.isOwner(owners[2]));

        assertEq(safe.getThreshold(), threshold);
    }

    function test_safeSubscriptionsModuleEnabled() public view {
        assertTrue(safe.isModuleEnabled(address(safeSubscriptions)));
    }

    function test_safeAddressSet() public view {
        assertEq(safeSubscriptions.getSafe(), address(safe));
    }

    function test_getNextNonce() public view {
        assertEq(safeSubscriptions.getNextNonce(), 1);
    }
}
