const PricingProtocol = artifacts.require("PricingProtocol");

module.exports = function (deployer) {
  deployer.deploy(PricingProtocol);
};
