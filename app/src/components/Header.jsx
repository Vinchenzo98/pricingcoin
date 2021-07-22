
import { Row, Col, Button } from 'react-bootstrap';


function Header() {
    
  return (
    <div className="gradient">
      
            <Row>
                <Col>   
                    <h1>Pricing Protocol</h1>
                </Col>
            </Row>
            <Row>
              <Col>
                <Button variant="primary">Discord</Button>
              </Col>
              <Col>
                <Button variant="outline-primary">Whitepaper</Button>
              </Col>
            </Row>
 
    
    </div>
  );
}

export default Header;
