
import React, {Component} from 'react';
import { Button, Container, Nav, Navbar} from 'react-bootstrap';
import {
    BrowserRouter as Router,
    Switch,
    Route,
    Link
}  from "react-router-dom";
import Session from "./mySessions";
import Main from "./main";
import Landing from './landing';
import "./main.css";

export default class NavBarComp extends Component {
    render(){
        return (
            <Router>
             <div> 
            <Navbar bg="light" expand="lg">
          <Container>
            <Navbar.Brand href="#home">Pricing Protocol</Navbar.Brand>
            <Navbar.Toggle aria-controls="basic-navbar-nav" />
            <Navbar.Collapse id="basic-navbar-nav">
              <Nav className="me-auto">
                <Nav.Link as={Link} to={"/home"}>Home</Nav.Link>
                <Nav.Link as={Link} to={"/live"}>Live Sessions</Nav.Link>
                <Nav.Link as={Link} to={"/sessions"}>My Sessions</Nav.Link>
                <Button>Connect</Button>
              </Nav>
            </Navbar.Collapse>
          </Container>
        </Navbar>
           </div>  
           <div>
           <Switch>
               <Route path="/home">
                    <Landing/>
                </Route>
                <Route path="/live">
                    <Main></Main>
                </Route>
                <Route path="/sessions">
                    <Session></Session>
                </Route>
           </Switch>    
            </div>
         

            </Router>
          
            );
    }
   
  }
  
  
