import React, { Component } from 'react'
import ShortingContract from '../build/contracts/Shorting.json'
import TokenOracleContract from '../build/contracts/TokenOracle.json'
import getWeb3 from './utils/getWeb3'

import './css/oswald.css'
import './css/open-sans.css'
import './css/pure-min.css'
import './App.css'

class App extends Component {
  constructor(props) {
    super(props)

    this.state = {
      filledShorts: [],
      web3: null
    }
  }

  componentWillMount() {
    // Get network provider and web3 instance.
    // See utils/getWeb3 for more info.

    getWeb3
    .then(results => {
      this.setState({
        web3: results.web3
      })

      // Instantiate contract once web3 provided.
      this.instantiateContract()
    })
    .catch(() => {
      console.log('Error finding web3.')
    })
  }

  instantiateContract() {
    /*
     * SMART CONTRACT EXAMPLE
     *
     * Normally these functions would be called in the context of a
     * state management library, but for convenience I've placed them here.
     */

    const contract = require('truffle-contract')
    const shorting = contract(ShortingContract)
    shorting.setProvider(this.state.web3.currentProvider)

    // Declaring this for later so we can chain functions on SimpleStorage.
    var shortingInstance

    // Get accounts.
    this.state.web3.eth.getAccounts(async (error, accounts) => {
      shortingInstance = await shorting.deployed()
      shorting.Filled({}, { fromBlock: 0, toBlock: 'latest' }).get((error, eventResult) => {
        if (error)
        console.log('Error in myEvent event handler: ' + error);
        else
        // console.log('myEvent: ' + JSON.stringify(eventResult.args));
        this.setState({filledShorts: eventResult})
      });
    })
  }

  render() {
    return (
      <div className="App">
        <nav className="navbar pure-menu pure-menu-horizontal">
            <a href="#" className="pure-menu-heading pure-menu-link">Truffle Box</a>
        </nav>

        <main className="container">
          <div className="pure-g">
            <div className="pure-u-1-1">
              <h1>Good to Go!</h1>
              <p>Your Truffle Box is installed and ready.</p>
              <h2>Smart Contract Example</h2>
              <div>
                {this.state.filledShorts}
              </div>
            </div>
          </div>
        </main>
      </div>
    );
  }
}

export default App
