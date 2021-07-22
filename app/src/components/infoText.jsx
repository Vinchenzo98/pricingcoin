
import './infoText.css';
import { Row, Col } from 'react-bootstrap';

function Info() {
  return (
    <div className="App">
       
            <Row>
                <Col className="left" md="auto" >   
                If you can’t find the NFT you’re looking for search for it here!
                </Col>
                <Col className="right" md="auto">
                Create a new pricing session by submitting your contract number here! 
                </Col>
            </Row>
    </div>
  );
}

export default Info;