// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

library calculateBaseLibrary {
        function calculateBase(uint finalAppraisalValue, uint userAppraisalValue) pure public returns(uint){
            if (104*finalAppraisalValue < 100* userAppraisalValue 
                && 105*finalAppraisalValue >= 100*userAppraisalValue) {
                return 1;
            }
            else if (103*finalAppraisalValue < 100*userAppraisalValue 
                && 104*finalAppraisalValue >= 100*userAppraisalValue) {
                return 2;
            }
            else if (102*finalAppraisalValue < 100* userAppraisalValue 
                && 103*finalAppraisalValue >= 100* userAppraisalValue) {
                return 3;
            }
            else if (101*finalAppraisalValue < 100*userAppraisalValue 
                && 102*finalAppraisalValue >= 100* userAppraisalValue) {
                return 4;
            }
            else if (100*finalAppraisalValue < 100*userAppraisalValue
                && 101*finalAppraisalValue >= 100* userAppraisalValue) {
                return 5;
            }
            else if (100*finalAppraisalValue == 100*userAppraisalValue) {
                return 6;
            }
            else if (100*finalAppraisalValue > 100*userAppraisalValue
                && 99*finalAppraisalValue <= 100*userAppraisalValue) {
                return 5;
            }
            else if (99*finalAppraisalValue > 100*userAppraisalValue
                && 98*finalAppraisalValue <= 100*userAppraisalValue) {
                return 4;
            }
            else if (98*finalAppraisalValue > 100*userAppraisalValue 
                && 97*finalAppraisalValue <= 100*userAppraisalValue) {
                return 3;
            }
            else if (97*finalAppraisalValue > 100*userAppraisalValue 
                && 96*finalAppraisalValue <= 100*userAppraisalValue) {
                return 2;
            }
            else if (96*finalAppraisalValue > 100*userAppraisalValue 
                && 95*finalAppraisalValue <= 100*userAppraisalValue) {
                return 1;
            }
            //In this case the user is out of the money
            else {
                return 0;
            }
        }
    }
