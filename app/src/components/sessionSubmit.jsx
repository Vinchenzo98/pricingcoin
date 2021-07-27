
import './submit.css';
import {Button, InputGroup, FormControl, Row, Col} from 'react-bootstrap';

function SessionSubmit() {
  return (
    <div className="App">
    
        <Row>
                <Col></Col>
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
     
    </div>
  );
}

export default SessionSubmit;
