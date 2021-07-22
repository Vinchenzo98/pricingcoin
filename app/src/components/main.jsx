
import './main.css';
import { Container, Row, Col } from 'react-bootstrap';
import Content from './content';

import Submit from './submit';

function Main() {
    
  return (
    <div className="App">
        <Container fluid>
            <Row className="mt-5">
                <Col>   
                    <h1>Active NFTs Pricing Sessions</h1>
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
             <Content className="BG"/>
            
             <Submit/>
        </Container>
    
    </div>
  );
}

export default Main;
