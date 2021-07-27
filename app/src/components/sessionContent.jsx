import React from 'react';
import logo from './NFT.jpg';
import './content.css';
import { Row, Col, Button, Modal, Image, InputGroup, FormControl } from 'react-bootstrap';
import users from './users';
import { useState } from 'react';
function SessionContent() {
    const [show, quickView] = useState(false);

    const handleClose =() => quickView(false);
    const handleShow = () => quickView(true);

    const [vote, setVote] =useState(false);

    const voteClose =() => setVote(false);
    const voteShow =() => setVote(true);
    
   
  return (
    <div className="users">
        {users.map( user => {

            return (
                <Row className="m-5">
                <Col className="sig">
                    {user.sig}
                </Col>
                <Col className="time">
                    {user.date}
                </Col>
                <Col className="time">
                    {user.participants}
                </Col>
                <Col className="time">
                    {user.stake}
                </Col>
                <Col className="view">
                     <a href={voteShow}>{user.view}</a>
                </Col>
                <Col className="button">
                <Button variant="secondary" onClick={handleShow}>{user.button}</Button>
                </Col>
            </Row>
                 

            )
        })}

      
        <Modal show={show} onHide={handleClose}>
        <Modal.Header>
          <Modal.Title>My Prcing Sessions</Modal.Title>
        </Modal.Header>
        <Modal.Body>
        <Row>
            <Image src={logo} rounded />

         </Row>
         <Row>
             <Col></Col>
             <Col><Button>Weight</Button></Col>
             <Col><Button>Set Final</Button></Col>
             <Col><Button>Calc Base</Button></Col>
             <Col><Button>Issue Coin</Button></Col>
             <Col><Button>Harvest</Button></Col>
             <Col></Col>
        </Row>
         <Row>
              <Col>
                <h4>Look up Address</h4>
                <InputGroup className="mb-3">
                    <FormControl
                    placeholder="NFT Address Here"
                    aria-label="Recipient's username"
                    aria-describedby="basic-addon2"
                    />
                    <Button variant="outline-secondary" id="button-addon2">
                    Submit
                    </Button>
                </InputGroup>
                </Col>
            </Row> 
      </Modal.Body>
        <Modal.Footer>
        

          <Button variant="secondary" onClick={handleClose}>
            Close
          </Button>
         <Button>
             Back to Main Page
         </Button>
        </Modal.Footer>
      </Modal>

      <Modal show={vote} onHide={voteClose}>
        <Modal.Header>
          <Modal.Title>My Pricing Sessions</Modal.Title>
        </Modal.Header>
        <Modal.Body>
        <Row>
        <Image src={logo} rounded />
         </Row>
        
        <Row>
        <Col>
                <h4>Look up Address</h4>
                <InputGroup className="mb-3">
                    <FormControl
                    placeholder="NFT Address Here"
                    aria-label="Recipient's username"
                    aria-describedby="basic-addon2"
                    />
                    <Button variant="outline-secondary" id="button-addon2">
                    Submit
                    </Button>
                </InputGroup>
                </Col>
               
         </Row>

        </Modal.Body>
        <Modal.Footer>
          <Button variant="secondary" onClick={voteClose}>
            Close
          </Button>
         
        </Modal.Footer>
      </Modal>
    
    </div>
  );
}

export default SessionContent;
