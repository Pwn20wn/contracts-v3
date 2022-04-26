/* Autogenerated file. Do not edit manually. */

/* tslint:disable */

/* eslint-disable */
import type {
  ExternalProtectionVault,
  ExternalProtectionVaultInterface,
} from "../../../contracts/vaults/ExternalProtectionVault";
import type { Provider, TransactionRequest } from "@ethersproject/providers";
import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";

const _abi = [
  {
    inputs: [
      {
        internalType: "contract ITokenGovernance",
        name: "initBNTGovernance",
        type: "address",
      },
      {
        internalType: "contract ITokenGovernance",
        name: "initVBNTGovernance",
        type: "address",
      },
    ],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    inputs: [],
    name: "AccessDenied",
    type: "error",
  },
  {
    inputs: [],
    name: "AlreadyInitialized",
    type: "error",
  },
  {
    inputs: [],
    name: "InvalidAddress",
    type: "error",
  },
  {
    inputs: [],
    name: "InvalidToken",
    type: "error",
  },
  {
    inputs: [],
    name: "NotPayable",
    type: "error",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "contract Token",
        name: "token",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "caller",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "FundsBurned",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "contract Token",
        name: "token",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "caller",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "target",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "FundsWithdrawn",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "account",
        type: "address",
      },
    ],
    name: "Paused",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "bytes32",
        name: "role",
        type: "bytes32",
      },
      {
        indexed: true,
        internalType: "bytes32",
        name: "previousAdminRole",
        type: "bytes32",
      },
      {
        indexed: true,
        internalType: "bytes32",
        name: "newAdminRole",
        type: "bytes32",
      },
    ],
    name: "RoleAdminChanged",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "bytes32",
        name: "role",
        type: "bytes32",
      },
      {
        indexed: true,
        internalType: "address",
        name: "account",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "sender",
        type: "address",
      },
    ],
    name: "RoleGranted",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "bytes32",
        name: "role",
        type: "bytes32",
      },
      {
        indexed: true,
        internalType: "address",
        name: "account",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "sender",
        type: "address",
      },
    ],
    name: "RoleRevoked",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "account",
        type: "address",
      },
    ],
    name: "Unpaused",
    type: "event",
  },
  {
    inputs: [],
    name: "DEFAULT_ADMIN_ROLE",
    outputs: [
      {
        internalType: "bytes32",
        name: "",
        type: "bytes32",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "contract Token",
        name: "token",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "burn",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes32",
        name: "role",
        type: "bytes32",
      },
    ],
    name: "getRoleAdmin",
    outputs: [
      {
        internalType: "bytes32",
        name: "",
        type: "bytes32",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes32",
        name: "role",
        type: "bytes32",
      },
      {
        internalType: "uint256",
        name: "index",
        type: "uint256",
      },
    ],
    name: "getRoleMember",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes32",
        name: "role",
        type: "bytes32",
      },
    ],
    name: "getRoleMemberCount",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes32",
        name: "role",
        type: "bytes32",
      },
      {
        internalType: "address",
        name: "account",
        type: "address",
      },
    ],
    name: "grantRole",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes32",
        name: "role",
        type: "bytes32",
      },
      {
        internalType: "address",
        name: "account",
        type: "address",
      },
    ],
    name: "hasRole",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "initialize",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "isPaused",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "isPayable",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "pure",
    type: "function",
  },
  {
    inputs: [],
    name: "pause",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "paused",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes",
        name: "data",
        type: "bytes",
      },
    ],
    name: "postUpgrade",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes32",
        name: "role",
        type: "bytes32",
      },
      {
        internalType: "address",
        name: "account",
        type: "address",
      },
    ],
    name: "renounceRole",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes32",
        name: "role",
        type: "bytes32",
      },
      {
        internalType: "address",
        name: "account",
        type: "address",
      },
    ],
    name: "revokeRole",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "roleAdmin",
    outputs: [
      {
        internalType: "bytes32",
        name: "",
        type: "bytes32",
      },
    ],
    stateMutability: "pure",
    type: "function",
  },
  {
    inputs: [],
    name: "roleAssetManager",
    outputs: [
      {
        internalType: "bytes32",
        name: "",
        type: "bytes32",
      },
    ],
    stateMutability: "pure",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes4",
        name: "interfaceId",
        type: "bytes4",
      },
    ],
    name: "supportsInterface",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "unpause",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "version",
    outputs: [
      {
        internalType: "uint16",
        name: "",
        type: "uint16",
      },
    ],
    stateMutability: "pure",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "contract Token",
        name: "token",
        type: "address",
      },
      {
        internalType: "address payable",
        name: "target",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "withdrawFunds",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    stateMutability: "payable",
    type: "receive",
  },
];

const _bytecode =
  "0x6101006040523480156200001257600080fd5b5060405162001eb338038062001eb3833981016040819052620000359162000191565b818181620000438162000150565b816200004f8162000150565b6001600160a01b03841660a081905260408051637e062a3560e11b8152905163fc0c546a916004808201926020929091908290030181865afa1580156200009a573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190620000c09190620001d0565b6001600160a01b03908116608052831660e081905260408051637e062a3560e11b8152905163fc0c546a916004808201926020929091908290030181865afa15801562000111573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190620001379190620001d0565b6001600160a01b031660c05250620001f7945050505050565b6001600160a01b038116620001785760405163e6c4247b60e01b815260040160405180910390fd5b50565b6001600160a01b03811681146200017857600080fd5b60008060408385031215620001a557600080fd5b8251620001b2816200017b565b6020840151909250620001c5816200017b565b809150509250929050565b600060208284031215620001e357600080fd5b8151620001f0816200017b565b9392505050565b60805160a05160c05160e051611c826200023160003960006109bd0152600061097e0152600061090a015260006108cb0152611c826000f3fe60806040526004361061012e5760003560e01c80638cd2403d116100ab5780639dc29fac1161006f5780639dc29fac1461034e578063a217fddf1461036e578063b187bd2614610383578063ca15c87314610398578063ce46e046146103b8578063d547741f146103cc57600080fd5b80638cd2403d146102825780639010d07c146102a257806391d14854146102da57806392bd95ea146102fa57806393867fb51461032d57600080fd5b80633f4ba83a116100f25780633f4ba83a1461020f57806354fd4d50146102245780635c975abb146102405780638129fc1c146102585780638456cb591461026d57600080fd5b806301ffc9a71461013c5780631c20fadd14610171578063248a9ca3146101915780632f2ff15d146101cf57806336568abe146101ef57600080fd5b3661013757005b005b600080fd5b34801561014857600080fd5b5061015c610157366004611862565b6103ec565b60405190151581526020015b60405180910390f35b34801561017d57600080fd5b5061013561018c3660046118a1565b610417565b34801561019d57600080fd5b506101c16101ac3660046118e2565b60009081526065602052604090206001015490565b604051908152602001610168565b3480156101db57600080fd5b506101356101ea3660046118fb565b61058d565b3480156101fb57600080fd5b5061013561020a3660046118fb565b6105b8565b34801561021b57600080fd5b50610135610636565b34801561023057600080fd5b5060405160018152602001610168565b34801561024c57600080fd5b5060fb5460ff1661015c565b34801561026457600080fd5b50610135610658565b34801561027957600080fd5b50610135610719565b34801561028e57600080fd5b5061013561029d36600461192b565b610739565b3480156102ae57600080fd5b506102c26102bd36600461199d565b61078a565b6040516001600160a01b039091168152602001610168565b3480156102e657600080fd5b5061015c6102f53660046118fb565b6107a9565b34801561030657600080fd5b507f89ce14d20697a788f57260f7690044299bde7ea88cfb7e43d120a0c031f1ffc16101c1565b34801561033957600080fd5b50600080516020611c568339815191526101c1565b34801561035a57600080fd5b506101356103693660046119bf565b6107d4565b34801561037a57600080fd5b506101c1600081565b34801561038f57600080fd5b5061015c610a9e565b3480156103a457600080fd5b506101c16103b33660046118e2565b610ab1565b3480156103c457600080fd5b50600161015c565b3480156103d857600080fd5b506101356103e73660046118fb565b610ac8565b60006001600160e01b03198216635a05180f60e01b1480610411575061041182610aee565b92915050565b8161042181610b23565b600261012d54036104795760405162461bcd60e51b815260206004820152601f60248201527f5265656e7472616e637947756172643a207265656e7472616e742063616c6c0060448201526064015b60405180910390fd5b600261012d5560fb5460ff16156104a25760405162461bcd60e51b8152600401610470906119eb565b338484846104b284848484610b4a565b6104cf57604051634ca8886760e01b815260040160405180910390fd5b851561057d5773eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee6001600160a01b038916036105115761050c6001600160a01b03881687610b7f565b610525565b6105256001600160a01b0389168888610c98565b866001600160a01b0316336001600160a01b0316896001600160a01b03167fc322efa58c9cb2c39cfffdac61d35c8643f5cbf13c6a7d0034de2cf18923aff38960405161057491815260200190565b60405180910390a45b5050600161012d55505050505050565b6000828152606560205260409020600101546105a98133610d19565b6105b38383610d7d565b505050565b6001600160a01b03811633146106285760405162461bcd60e51b815260206004820152602f60248201527f416363657373436f6e74726f6c3a2063616e206f6e6c792072656e6f756e636560448201526e103937b632b9903337b91039b2b63360891b6064820152608401610470565b6106328282610d9f565b5050565b61064e600080516020611c5683398151915233610dc1565b610656610de8565b565b600054610100900460ff166106735760005460ff1615610677565b303b155b6106da5760405162461bcd60e51b815260206004820152602e60248201527f496e697469616c697a61626c653a20636f6e747261637420697320616c72656160448201526d191e481a5b9a5d1a585b1a5e995960921b6064820152608401610470565b600054610100900460ff161580156106fc576000805461ffff19166101011790555b610704610e7b565b8015610716576000805461ff00191690555b50565b610731600080516020611c5683398151915233610dc1565b610656610eb2565b60c95460009061074e9061ffff166001611a2b565b905061ffff81166001146107745760405162dc149f60e41b815260040160405180910390fd5b60c9805461ffff191661ffff8316179055505050565b60008281526097602052604081206107a29083610f0a565b9392505050565b60009182526065602090815260408084206001600160a01b0393909316845291905290205460ff1690565b600261012d54036108275760405162461bcd60e51b815260206004820152601f60248201527f5265656e7472616e637947756172643a207265656e7472616e742063616c6c006044820152606401610470565b600261012d5560fb5460ff16156108505760405162461bcd60e51b8152600401610470906119eb565b338260008361086184848484610b4a565b61087e57604051634ca8886760e01b815260040160405180910390fd5b8415610a905773eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee6001600160a01b038716036108c15760405163c1ab6dc160e01b815260040160405180910390fd5b6001600160a01b037f000000000000000000000000000000000000000000000000000000000000000081169087160361097457604051630852cd8d60e31b8152600481018690527f00000000000000000000000000000000000000000000000000000000000000006001600160a01b0316906342966c68906024015b600060405180830381600087803b15801561095757600080fd5b505af115801561096b573d6000803e3d6000fd5b50505050610a4f565b6001600160a01b037f00000000000000000000000000000000000000000000000000000000000000008116908716036109f457604051630852cd8d60e31b8152600481018690527f00000000000000000000000000000000000000000000000000000000000000006001600160a01b0316906342966c689060240161093d565b604051630852cd8d60e31b8152600481018690526001600160a01b038716906342966c6890602401600060405180830381600087803b158015610a3657600080fd5b505af1158015610a4a573d6000803e3d6000fd5b505050505b60405185815233906001600160a01b038816907fd3fda22e13f8cb743a9ceaca6e14022b6677188d20f3c3047f5c9033e07a4e879060200160405180910390a35b5050600161012d5550505050565b6000610aac60fb5460ff1690565b905090565b600081815260976020526040812061041190610f16565b600082815260656020526040902060010154610ae48133610d19565b6105b38383610d9f565b60006001600160e01b03198216637965db0b60e01b148061041157506301ffc9a760e01b6001600160e01b0319831614610411565b6001600160a01b0381166107165760405163e6c4247b60e01b815260040160405180910390fd5b6000610b767f89ce14d20697a788f57260f7690044299bde7ea88cfb7e43d120a0c031f1ffc1866107a9565b95945050505050565b80471015610bcf5760405162461bcd60e51b815260206004820152601d60248201527f416464726573733a20696e73756666696369656e742062616c616e63650000006044820152606401610470565b6000826001600160a01b03168260405160006040518083038185875af1925050503d8060008114610c1c576040519150601f19603f3d011682016040523d82523d6000602084013e610c21565b606091505b50509050806105b35760405162461bcd60e51b815260206004820152603a60248201527f416464726573733a20756e61626c6520746f2073656e642076616c75652c207260448201527f6563697069656e74206d617920686176652072657665727465640000000000006064820152608401610470565b80600003610ca557505050565b73eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee6001600160a01b03841603610d05576040516001600160a01b0383169082156108fc029083906000818181858888f19350505050158015610cff573d6000803e3d6000fd5b50505050565b6105b36001600160a01b0384168383610f20565b610d2382826107a9565b61063257610d3b816001600160a01b03166014610f72565b610d46836020610f72565b604051602001610d57929190611a7d565b60408051601f198184030181529082905262461bcd60e51b825261047091600401611af2565b610d87828261110e565b60008281526097602052604090206105b39082611194565b610da982826111a9565b60008281526097602052604090206105b39082611210565b610dcb82826107a9565b61063257604051634ca8886760e01b815260040160405180910390fd5b60fb5460ff16610e315760405162461bcd60e51b815260206004820152601460248201527314185d5cd8589b194e881b9bdd081c185d5cd95960621b6044820152606401610470565b60fb805460ff191690557f5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa335b6040516001600160a01b03909116815260200160405180910390a1565b600054610100900460ff16610ea25760405162461bcd60e51b815260040161047090611b25565b610eaa611225565b61065661126c565b60fb5460ff1615610ed55760405162461bcd60e51b8152600401610470906119eb565b60fb805460ff191660011790557f62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258610e5e3390565b60006107a283836112cb565b6000610411825490565b604080516001600160a01b038416602482015260448082018490528251808303909101815260649091019091526020810180516001600160e01b031663a9059cbb60e01b1790526105b39084906112f5565b60606000610f81836002611b70565b610f8c906002611b8f565b67ffffffffffffffff811115610fa457610fa4611ba7565b6040519080825280601f01601f191660200182016040528015610fce576020820181803683370190505b509050600360fc1b81600081518110610fe957610fe9611bbd565b60200101906001600160f81b031916908160001a905350600f60fb1b8160018151811061101857611018611bbd565b60200101906001600160f81b031916908160001a905350600061103c846002611b70565b611047906001611b8f565b90505b60018111156110bf576f181899199a1a9b1b9c1cb0b131b232b360811b85600f166010811061107b5761107b611bbd565b1a60f81b82828151811061109157611091611bbd565b60200101906001600160f81b031916908160001a90535060049490941c936110b881611bd3565b905061104a565b5083156107a25760405162461bcd60e51b815260206004820181905260248201527f537472696e67733a20686578206c656e67746820696e73756666696369656e746044820152606401610470565b61111882826107a9565b6106325760008281526065602090815260408083206001600160a01b03851684529091529020805460ff191660011790556111503390565b6001600160a01b0316816001600160a01b0316837f2f8788117e7eff1d82e926ec794901d17c78024a50270940304540a733656f0d60405160405180910390a45050565b60006107a2836001600160a01b0384166113c7565b6111b382826107a9565b156106325760008281526065602090815260408083206001600160a01b0385168085529252808320805460ff1916905551339285917ff6391f5c32d9c69d2a47ea670b442974b53935d1edc7fd64eb21e047a839171b9190a45050565b60006107a2836001600160a01b038416611416565b600054610100900460ff1661124c5760405162461bcd60e51b815260040161047090611b25565b611254611509565b61125c611540565b61126461156f565b61065661159e565b600054610100900460ff166112935760405162461bcd60e51b815260040161047090611b25565b6106567f89ce14d20697a788f57260f7690044299bde7ea88cfb7e43d120a0c031f1ffc1600080516020611c568339815191526115c5565b60008260000182815481106112e2576112e2611bbd565b9060005260206000200154905092915050565b600061134a826040518060400160405280602081526020017f5361666545524332303a206c6f772d6c6576656c2063616c6c206661696c6564815250856001600160a01b03166116109092919063ffffffff16565b8051909150156105b357808060200190518101906113689190611bea565b6105b35760405162461bcd60e51b815260206004820152602a60248201527f5361666545524332303a204552433230206f7065726174696f6e20646964206e6044820152691bdd081cdd58d8d9595960b21b6064820152608401610470565b600081815260018301602052604081205461140e57508154600181810184556000848152602080822090930184905584548482528286019093526040902091909155610411565b506000610411565b600081815260018301602052604081205480156114ff57600061143a600183611c0c565b855490915060009061144e90600190611c0c565b90508181146114b357600086600001828154811061146e5761146e611bbd565b906000526020600020015490508087600001848154811061149157611491611bbd565b6000918252602080832090910192909255918252600188019052604090208390555b85548690806114c4576114c4611c23565b600190038181906000526020600020016000905590558560010160008681526020019081526020016000206000905560019350505050610411565b6000915050610411565b600054610100900460ff166115305760405162461bcd60e51b815260040161047090611b25565b61153861159e565b610656611627565b600054610100900460ff166115675760405162461bcd60e51b815260040161047090611b25565b61065661168c565b600054610100900460ff166115965760405162461bcd60e51b815260040161047090611b25565b6106566116bf565b600054610100900460ff166106565760405162461bcd60e51b815260040161047090611b25565b600082815260656020526040808220600101805490849055905190918391839186917fbd79b86ffe0ab8e8776151514217cd7cacd52c909f66475c3af44e129f0b00ff9190a4505050565b606061161f84846000856116ee565b949350505050565b600054610100900460ff1661164e5760405162461bcd60e51b815260040161047090611b25565b60c9805461ffff19166001179055611674600080516020611c56833981519152806115c5565b610656600080516020611c568339815191523361181f565b600054610100900460ff166116b35760405162461bcd60e51b815260040161047090611b25565b60fb805460ff19169055565b600054610100900460ff166116e65760405162461bcd60e51b815260040161047090611b25565b600161012d55565b60608247101561174f5760405162461bcd60e51b815260206004820152602660248201527f416464726573733a20696e73756666696369656e742062616c616e636520666f6044820152651c8818d85b1b60d21b6064820152608401610470565b6001600160a01b0385163b6117a65760405162461bcd60e51b815260206004820152601d60248201527f416464726573733a2063616c6c20746f206e6f6e2d636f6e74726163740000006044820152606401610470565b600080866001600160a01b031685876040516117c29190611c39565b60006040518083038185875af1925050503d80600081146117ff576040519150601f19603f3d011682016040523d82523d6000602084013e611804565b606091505b5091509150611814828286611829565b979650505050505050565b6106328282610d7d565b606083156118385750816107a2565b8251156118485782518084602001fd5b8160405162461bcd60e51b81526004016104709190611af2565b60006020828403121561187457600080fd5b81356001600160e01b0319811681146107a257600080fd5b6001600160a01b038116811461071657600080fd5b6000806000606084860312156118b657600080fd5b83356118c18161188c565b925060208401356118d18161188c565b929592945050506040919091013590565b6000602082840312156118f457600080fd5b5035919050565b6000806040838503121561190e57600080fd5b8235915060208301356119208161188c565b809150509250929050565b6000806020838503121561193e57600080fd5b823567ffffffffffffffff8082111561195657600080fd5b818501915085601f83011261196a57600080fd5b81358181111561197957600080fd5b86602082850101111561198b57600080fd5b60209290920196919550909350505050565b600080604083850312156119b057600080fd5b50508035926020909101359150565b600080604083850312156119d257600080fd5b82356119dd8161188c565b946020939093013593505050565b60208082526010908201526f14185d5cd8589b194e881c185d5cd95960821b604082015260600190565b634e487b7160e01b600052601160045260246000fd5b600061ffff808316818516808303821115611a4857611a48611a15565b01949350505050565b60005b83811015611a6c578181015183820152602001611a54565b83811115610cff5750506000910152565b7f416363657373436f6e74726f6c3a206163636f756e7420000000000000000000815260008351611ab5816017850160208801611a51565b7001034b99036b4b9b9b4b733903937b6329607d1b6017918401918201528351611ae6816028840160208801611a51565b01602801949350505050565b6020815260008251806020840152611b11816040850160208701611a51565b601f01601f19169190910160400192915050565b6020808252602b908201527f496e697469616c697a61626c653a20636f6e7472616374206973206e6f74206960408201526a6e697469616c697a696e6760a81b606082015260800190565b6000816000190483118215151615611b8a57611b8a611a15565b500290565b60008219821115611ba257611ba2611a15565b500190565b634e487b7160e01b600052604160045260246000fd5b634e487b7160e01b600052603260045260246000fd5b600081611be257611be2611a15565b506000190190565b600060208284031215611bfc57600080fd5b815180151581146107a257600080fd5b600082821015611c1e57611c1e611a15565b500390565b634e487b7160e01b600052603160045260246000fd5b60008251611c4b818460208701611a51565b919091019291505056fe2172861495e7b85edac73e3cd5fbb42dd675baadf627720e687bcfdaca025096a164736f6c634300080d000a";

type ExternalProtectionVaultConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: ExternalProtectionVaultConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class ExternalProtectionVault__factory extends ContractFactory {
  constructor(...args: ExternalProtectionVaultConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
  }

  override deploy(
    initBNTGovernance: string,
    initVBNTGovernance: string,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ExternalProtectionVault> {
    return super.deploy(
      initBNTGovernance,
      initVBNTGovernance,
      overrides || {}
    ) as Promise<ExternalProtectionVault>;
  }
  override getDeployTransaction(
    initBNTGovernance: string,
    initVBNTGovernance: string,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(
      initBNTGovernance,
      initVBNTGovernance,
      overrides || {}
    );
  }
  override attach(address: string): ExternalProtectionVault {
    return super.attach(address) as ExternalProtectionVault;
  }
  override connect(signer: Signer): ExternalProtectionVault__factory {
    return super.connect(signer) as ExternalProtectionVault__factory;
  }

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): ExternalProtectionVaultInterface {
    return new utils.Interface(_abi) as ExternalProtectionVaultInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): ExternalProtectionVault {
    return new Contract(
      address,
      _abi,
      signerOrProvider
    ) as ExternalProtectionVault;
  }
}