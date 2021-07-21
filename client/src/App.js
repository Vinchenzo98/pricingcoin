import './App.css';
import { SocialIcon } from 'react-social-icons';

function App() {

  return (
    <div className="App">
      <header className="App-header">
        <h1> Pricing Protocol is coming soon!  </h1>
        <p>
        Read our whitepaper <a href="https://github.com/alangindi/pricingcoin/blob/main/_Informal%20PricingProtocol%20White%20Paper.pdf">here</a>.
        <br />
        <br /> 
        Stay up to date with us on Twitter, Github, and Discord.
        <br />
        <br />
          <SocialIcon className="social" url="https://twitter.com/PricingProtocol" />
          <SocialIcon className="social" url="https://github.com/alangindi/pricingcoin" />
          <SocialIcon className="social" url="https://discord.gg/dSVWkcqCxS" />
        </p> 
      </header>
    </div>
  )
}