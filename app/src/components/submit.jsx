
import './submit.css';
import {Button, InputGroup, FormControl, Row, Col, Container } from 'react-bootstrap';

function Submit() {
  return (
    <div className="App">
    
        <Row>
                <Col></Col>
                <Col className="xs-2">   
                <InputGroup className="mb-4">
                    <FormControl
                    placeholder="Find NFT"
                    aria-label="Recipient's username"
                    aria-describedby="basic-addon2"
                    />
                    <Button variant="outline-secondary" id="button-addon2">
                    Search
                    </Button>
                </InputGroup>
                </Col>
                <Col>   
                <InputGroup className="mb-3">
                    <FormControl
                    placeholder="Submit New Session"
                    aria-label="Recipient's username"
                    aria-describedby="basic-addon2"
                    />
                    <Button variant="outline-secondary" id="button-addon2">
                    Submit
                    </Button>
                </InputGroup>
                </Col>
                <Col></Col>
            </Row>
            <Row>
                <Col></Col>
                <Col>
                <h4>Lookup Past NFT Pricing Sessions</h4>
                <InputGroup className="mb-3">
                    <FormControl
                    placeholder="Submit New Session"
                    aria-label="Recipient's username"
                    aria-describedby="basic-addon2"
                    />
                    <Button variant="outline-secondary" id="button-addon2">
                    Submit
                    </Button>
                </InputGroup>
                </Col>
                <Col></Col>
            </Row>

     

           
    </div>
  );
}

export default Submit;
