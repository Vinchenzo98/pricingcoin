// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

library harvestLossLibrary {
    
    function harvestUserOver(uint _stake, uint _userAppraisal, uint _finalAppraisal) pure public returns(uint) {
        return _stake * (_userAppraisal*100 - 105*_finalAppraisal)/(_finalAppraisal*100);
    }
    
    function harvestLossUnder(uint _stake, uint _userAppraisal, uint _finalAppraisal) pure public returns(uint) {
        return _stake * (95*_finalAppraisal - 100*_userAppraisal)/(_finalAppraisal*100);
    }
}