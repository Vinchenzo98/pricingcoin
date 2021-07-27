
import './main.css';
import { Container, Row, Col} from 'react-bootstrap';
import SessionContent from './sessionContent';

import SessionSubmit from './sessionSubmit';

function Session() {
    
  return (
    <div>
        <Container fluid>
            <Row className="mt-5">
                <Col>   
                    <h1>My Pricing Sessions</h1>
                </Col>
            </Row>
            <Row className="heading mt-5">
                <Col xs={1}></Col>
            <Col>
                 NFT Contract
                </Col>
                <Col xs={2}></Col>
                <Col >
                 End Time
                </Col>
              
                <Col>
                 Participants
                </Col>
                
                <Col>
                 Stake
                </Col>
               
                <Col className="view">
                 Quick View
                </Col>
                <Col >
                 Click
                </Col>
                <Col xs={1}></Col>
            </Row>
             <SessionContent/> 
             <SessionSubmit/>
             
        </Container>
    </div>
  );
}

export default Session;
